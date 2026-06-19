import Foundation
import RecursiveTextSplit

/// Counts tokens asynchronously for budgeting decisions.
public protocol AsyncTokenCounter: Sendable {
    var contextSize: Int { get }
    func tokenCount(forPrompt text: String) async throws -> Int
    func tokenCount(forInstructions text: String) async throws -> Int
}

public protocol TextLengthCounter: Sendable {
    func length(of text: String) -> Int
    var contextSize: Int { get }
}

/// Character-based estimator aligned with Apple TN3193 (~3.5 Latin chars per token).
public struct HeuristicTextLengthCounter: TextLengthCounter {
    public static let defaultContextSize = 4096
    private static let latinCharactersPerToken = 3.5

    public let contextSize: Int

    public init(contextSize: Int = Self.defaultContextSize) {
        self.contextSize = contextSize
    }

    public func length(of text: String) -> Int {
        Self.estimatedTokenCount(for: text)
    }

    public static func estimatedTokenCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let hasCJK = text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x4E00 ... 0x9FFF, 0x3040 ... 0x30FF, 0xAC00 ... 0xD7AF:
                true
            default:
                false
            }
        }
        if hasCJK {
            return text.count
        }
        return Int(ceil(Double(text.count) / latinCharactersPerToken))
    }
}

public struct TokenBudget: Sendable {
    private static let instructionSafetyMargin = 64

    private let tokenCounter: any AsyncTokenCounter

    public init(tokenCounter: any AsyncTokenCounter = FoundationModelsTokenCounter()) {
        self.tokenCounter = tokenCounter
    }

    public func fitsInOnePass(
        profile: TransformChunkingProfile,
        instructions: String,
        input: String
    ) async throws -> Bool {
        let instructionTokens = try await tokenCounter.tokenCount(forInstructions: instructions)
        let inputTokens = try await tokenCounter.tokenCount(forPrompt: input)
        let total = instructionTokens + inputTokens + profile.outputTokenReserve
        return total <= tokenCounter.contextSize
    }

    public func maxInputTokens(
        profile: TransformChunkingProfile,
        instructions: String
    ) async throws -> Int {
        let instructionTokens = try await tokenCounter.tokenCount(forInstructions: instructions)
        let available = tokenCounter.contextSize
            - instructionTokens
            - profile.outputTokenReserve
            - Self.instructionSafetyMargin
        return max(available, 1)
    }

    public func fitsInBudget(
        instructions: String,
        input: String,
        outputReserve: Int
    ) async throws -> Bool {
        let instructionTokens = try await tokenCounter.tokenCount(forInstructions: instructions)
        let inputTokens = try await tokenCounter.tokenCount(forPrompt: input)
        let total = instructionTokens + inputTokens + outputReserve
        return total <= tokenCounter.contextSize
    }

    public func split(
        profile: TransformChunkingProfile,
        instructions: String,
        input: String
    ) async throws -> [String] {
        let maxTokens = try await maxInputTokens(profile: profile, instructions: instructions)
        let lengthFunction = try await splitLengthFunction(for: input)
        let config = profile.split.makeConfig(chunkSize: maxTokens)
        let splitter = RecursiveCharacterTextSplitter(
            config: config,
            lengthFunction: lengthFunction
        )
        let chunks = splitter.split(text: input)
        guard !chunks.isEmpty else { return [input] }

        var validated: [String] = []
        for chunk in chunks {
            try validated.append(
                contentsOf: subdivideOversizedChunks(
                    chunk,
                    maxTokens: maxTokens,
                    profile: profile,
                    lengthFunction: lengthFunction
                )
            )
        }

        for chunk in validated {
            let count = try await tokenCounter.tokenCount(forPrompt: chunk)
            if count > maxTokens {
                throw GenerationError.contextWindowExceeded
            }
        }
        return validated
    }

    /// Heuristic token estimates can diverge from Foundation Models `tokenCount` (often ~20–35% low
    /// on Latin prose). When FM counting is available, calibrate the splitter length function from
    /// a short prefix so chunks stay under budget after FM validation.
    private func splitLengthFunction(for input: String) async throws -> @Sendable (String) -> Int {
        if #available(macOS 26.4, *) {
            let ratio = try await heuristicToFMRatio(sampleFrom: input)
            return { text in
                let heuristic = HeuristicTextLengthCounter.estimatedTokenCount(for: text)
                return Int(ceil(Double(heuristic) * ratio))
            }
        }
        return HeuristicTextLengthCounter.estimatedTokenCount
    }

    @available(macOS 26.4, *)
    private func heuristicToFMRatio(sampleFrom input: String) async throws -> Double {
        let sampleSize = min(input.count, 512)
        guard sampleSize > 0 else { return 1.0 }
        let sample = String(input.prefix(sampleSize))
        let heuristic = HeuristicTextLengthCounter.estimatedTokenCount(for: sample)
        guard heuristic > 0 else { return 1.0 }
        let fm = try await tokenCounter.tokenCount(forPrompt: sample)
        return max(Double(fm) / Double(heuristic), 1.0)
    }

    private func subdivideOversizedChunks(
        _ chunk: String,
        maxTokens: Int,
        profile: TransformChunkingProfile,
        lengthFunction: @escaping @Sendable (String) -> Int
    ) throws -> [String] {
        if lengthFunction(chunk) <= maxTokens {
            return [chunk]
        }
        let smallerConfig = profile.split.makeConfig(chunkSize: max(1, maxTokens / 2))
        let splitter = RecursiveCharacterTextSplitter(
            config: smallerConfig,
            lengthFunction: lengthFunction
        )
        let pieces = splitter.split(text: chunk)
        guard pieces.count > 1 else {
            return [chunk]
        }
        return try pieces.flatMap {
            try subdivideOversizedChunks(
                $0,
                maxTokens: maxTokens,
                profile: profile,
                lengthFunction: lengthFunction
            )
        }
    }
}

/// Fixed token counts for unit tests.
public struct FixedTextLengthCounter: TextLengthCounter {
    private let counts: [String: Int]
    public let contextSize: Int
    public let defaultLength: Int

    public init(
        contextSize: Int = 4096,
        defaultLength: Int = 10,
        counts: [String: Int] = [:]
    ) {
        self.contextSize = contextSize
        self.defaultLength = defaultLength
        self.counts = counts
    }

    public func length(of text: String) -> Int {
        counts[text] ?? defaultLength
    }
}

public struct SynchronousTokenBudget: Sendable {
    private static let instructionSafetyMargin = 64
    private let counter: any TextLengthCounter

    public init(counter: any TextLengthCounter) {
        self.counter = counter
    }

    public func fitsInOnePass(
        profile: TransformChunkingProfile,
        instructions: String,
        input: String
    ) -> Bool {
        let total = counter.length(of: instructions)
            + counter.length(of: input)
            + profile.outputTokenReserve
        return total <= counter.contextSize
    }

    public func maxInputTokens(profile: TransformChunkingProfile, instructions: String) -> Int {
        let available = counter.contextSize
            - counter.length(of: instructions)
            - profile.outputTokenReserve
            - Self.instructionSafetyMargin
        return max(available, 1)
    }

    public func containsWithinBudget(
        instructions: String,
        input: String,
        outputReserve: Int
    ) -> Bool {
        let total = counter.length(of: instructions)
            + counter.length(of: input)
            + outputReserve
        return total <= counter.contextSize
    }

    public func splitSynchronously(
        profile: TransformChunkingProfile,
        instructions: String,
        input: String
    ) throws -> [String] {
        let maxTokens = maxInputTokens(profile: profile, instructions: instructions)
        let config = profile.split.makeConfig(chunkSize: maxTokens)
        let counter = counter
        let splitter = RecursiveCharacterTextSplitter(config: config) { counter.length(of: $0) }
        let chunks = splitter.split(text: input)
        guard !chunks.isEmpty else { return [input] }
        for chunk in chunks where counter.length(of: chunk) > maxTokens {
            throw GenerationError.contextWindowExceeded
        }
        return chunks
    }
}
