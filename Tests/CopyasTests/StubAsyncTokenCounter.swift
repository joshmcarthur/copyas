@testable import Copyas
import Foundation

/// Stub `AsyncTokenCounter` for unit tests. Inject into `TokenBudget` instead of
/// `FoundationModelsTokenCounter` when Apple Intelligence is unavailable (e.g. CI).
///
/// - `promptCounts` / `instructionsCounts` — per-string overrides (like `FixedTextLengthCounter`)
/// - `promptScale` — multiply heuristic estimates to simulate FM counting more tokens than TN3193
/// - `instructionsLength` — fixed instruction token count regardless of text
struct StubAsyncTokenCounter: AsyncTokenCounter {
    let contextSize: Int
    private let promptCounts: [String: Int]
    private let instructionsCounts: [String: Int]
    private let defaultPromptLength: Int
    private let defaultInstructionsLength: Int
    private let promptScale: Double
    private let fixedInstructionsLength: Int?

    init(
        contextSize: Int = 4096,
        defaultPromptLength: Int = 10,
        defaultInstructionsLength: Int = 10,
        promptCounts: [String: Int] = [:],
        instructionsCounts: [String: Int] = [:],
        promptScale: Double = 1.0,
        fixedInstructionsLength: Int? = nil
    ) {
        self.contextSize = contextSize
        self.defaultPromptLength = defaultPromptLength
        self.defaultInstructionsLength = defaultInstructionsLength
        self.promptCounts = promptCounts
        self.instructionsCounts = instructionsCounts
        self.promptScale = promptScale
        self.fixedInstructionsLength = fixedInstructionsLength
    }

    func tokenCount(forPrompt text: String) async throws -> Int {
        if promptScale != 1.0 {
            return Int(ceil(
                Double(HeuristicTextLengthCounter.estimatedTokenCount(for: text)) * promptScale
            ))
        }
        return promptCounts[text] ?? defaultPromptLength
    }

    func tokenCount(forInstructions text: String) async throws -> Int {
        if let fixedInstructionsLength {
            return fixedInstructionsLength
        }
        return instructionsCounts[text] ?? defaultInstructionsLength
    }
}
