@testable import Copyas
import XCTest

final class TokenBudgetTests: XCTestCase {
    func testFitsInOnePassWhenUnderContextLimit() {
        let counter = FixedTextLengthCounter(contextSize: 10000, defaultLength: 10)
        let budget = SynchronousTokenBudget(counter: counter)
        let profile = Transform.pirate.chunkingProfile

        XCTAssertTrue(
            budget.fitsInOnePass(
                profile: profile,
                instructions: "instructions",
                input: "short"
            )
        )
    }

    func testSplitProducesMultipleChunksForLongInput() throws {
        let counter = FixedTextLengthCounter(contextSize: 10000, defaultLength: 50)
        let budget = SynchronousTokenBudget(counter: counter)
        let profile = Transform.pirate.chunkingProfile
        let input = String(repeating: "word ", count: 200)

        let chunks = try budget.splitSynchronously(
            profile: profile,
            instructions: "x",
            input: input
        )
        XCTAssertGreaterThan(chunks.count, 1)
    }

    func testHeuristicEstimatesLatinTextWithCeiling() {
        let estimate = HeuristicTextLengthCounter.estimatedTokenCount(for: "abcdefghij")
        XCTAssertEqual(estimate, 3)
    }

    func testLongInputNeedsChunkingWithHeuristicCounter() {
        let budget = SynchronousTokenBudget(counter: HeuristicTextLengthCounter())
        let profile = Transform.pirate.chunkingProfile
        let input = String(repeating: "word ", count: 10000)
        XCTAssertFalse(
            budget.fitsInOnePass(
                profile: profile,
                instructions: Transform.pirate.instructions,
                input: input
            )
        )
    }

    func testContainsWithinBudget() {
        let counter = FixedTextLengthCounter(contextSize: 100, defaultLength: 10)
        let budget = SynchronousTokenBudget(counter: counter)
        XCTAssertTrue(budget.containsWithinBudget(instructions: "a", input: "b", outputReserve: 10))
        XCTAssertFalse(budget.containsWithinBudget(
            instructions: "a",
            input: "b",
            outputReserve: 90
        ))
    }

    func testSplitThrowsWhenChunkExceedsBudget() {
        let counter = FixedTextLengthCounter(
            contextSize: 200,
            defaultLength: 10,
            counts: ["oversized": 5000]
        )
        let budget = SynchronousTokenBudget(counter: counter)
        let profile = Transform.pirate.chunkingProfile

        XCTAssertThrowsError(
            try budget.splitSynchronously(
                profile: profile,
                instructions: "x",
                input: "oversized"
            )
        ) { error in
            XCTAssertEqual(error as? GenerationError, .contextWindowExceeded)
        }
    }

    func testMaxInputTokensReservesOutputAndInstructions() {
        let counter = FixedTextLengthCounter(contextSize: 1000, defaultLength: 100)
        let budget = SynchronousTokenBudget(counter: counter)
        let profile = Transform.summary.chunkingProfile
        let maxInput = budget.maxInputTokens(profile: profile, instructions: "map")
        XCTAssertLessThan(maxInput, counter.contextSize)
    }

    func testHeuristicCJKUsesCharacterCount() {
        let estimate = HeuristicTextLengthCounter.estimatedTokenCount(for: "你好世界")
        XCTAssertEqual(estimate, 4)
    }

    func testHeuristicEmptyStringReturnsZero() {
        XCTAssertEqual(HeuristicTextLengthCounter.estimatedTokenCount(for: ""), 0)
    }

    func testAsyncFitsInOnePassWithFakeCounter() async throws {
        let budget = TokenBudget(tokenCounter: FakeAsyncTokenCounter(defaultLength: 10))
        let profile = Transform.pirate.chunkingProfile
        let fits = try await budget.fitsInOnePass(
            profile: profile,
            instructions: "brief",
            input: "short text"
        )
        XCTAssertTrue(fits)
    }

    func testAsyncFitsInBudgetWithFakeCounter() async throws {
        let budget = TokenBudget(tokenCounter: FakeAsyncTokenCounter(
            contextSize: 100,
            defaultLength: 10
        ))
        let withinBudget = try await budget.fitsInBudget(
            instructions: "a",
            input: "b",
            outputReserve: 10
        )
        XCTAssertTrue(withinBudget)
        let overBudget = try await budget.fitsInBudget(
            instructions: "a",
            input: "b",
            outputReserve: 90
        )
        XCTAssertFalse(overBudget)
    }

    func testAsyncMaxInputTokensWithFakeCounter() async throws {
        let counter = FakeAsyncTokenCounter(contextSize: 1000, defaultLength: 100)
        let budget = TokenBudget(tokenCounter: counter)
        let profile = Transform.summary.chunkingProfile
        let maxInput = try await budget.maxInputTokens(
            profile: profile,
            instructions: "map"
        )
        XCTAssertLessThan(maxInput, counter.contextSize)
    }

    func testAsyncSplitProducesMultipleChunksWithFakeCounter() async throws {
        let profile = TransformChunkingProfile(
            mode: .mapOnly,
            merge: .concatenate(separator: "\n\n"),
            outputTokenReserve: 50
        )
        let budget = TokenBudget(tokenCounter: FakeAsyncTokenCounter(contextSize: 500))
        let input = String(repeating: "word ", count: 200)
        let chunks = try await budget.split(
            profile: profile,
            instructions: "x",
            input: input
        )
        XCTAssertGreaterThan(chunks.count, 1)
    }

    func testAsyncSplitCalibratesWhenPromptCountsExceedHeuristic() async throws {
        let budget = TokenBudget(tokenCounter: FakeAsyncTokenCounter(
            contextSize: 4096,
            promptScale: 1.35,
            instructionsLength: 112
        ))
        let profile = Transform.pirate.chunkingProfile
        let input = String(repeating: "Paragraph one.\n\n", count: 800)
        let chunks = try await budget.split(
            profile: profile,
            instructions: Transform.pirate.instructions,
            input: input
        )
        XCTAssertGreaterThan(chunks.count, 1)
        let maxTokens = try await budget.maxInputTokens(
            profile: profile,
            instructions: Transform.pirate.instructions
        )
        for chunk in chunks {
            let count = try await FakeAsyncTokenCounter(
                contextSize: 4096,
                promptScale: 1.35,
                instructionsLength: 112
            ).tokenCount(forPrompt: chunk)
            XCTAssertLessThanOrEqual(count, maxTokens)
        }
    }

    func testAsyncSplitThrowsWhenChunkExceedsBudget() async {
        let budget = TokenBudget(tokenCounter: FakeAsyncTokenCounter(
            contextSize: 200,
            defaultLength: 10,
            counts: ["oversized": 5000]
        ))
        let profile = Transform.pirate.chunkingProfile

        do {
            _ = try await budget.split(
                profile: profile,
                instructions: "x",
                input: "oversized"
            )
            XCTFail("expected context window exceeded")
        } catch let error as GenerationError {
            XCTAssertEqual(error, .contextWindowExceeded)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAsyncSplitReturnsInputWhenSplitterProducesNoChunks() async throws {
        let budget = TokenBudget(tokenCounter: FakeAsyncTokenCounter())
        let profile = Transform.pirate.chunkingProfile
        let chunks = try await budget.split(
            profile: profile,
            instructions: "x",
            input: ""
        )
        XCTAssertEqual(chunks, [""])
    }
}

private struct FakeAsyncTokenCounter: AsyncTokenCounter {
    private let backing: FixedTextLengthCounter
    private let promptScale: Double
    private let instructionsLength: Int?

    init(
        contextSize: Int = 4096,
        defaultLength: Int = 10,
        counts: [String: Int] = [:],
        promptScale: Double = 1.0,
        instructionsLength: Int? = nil
    ) {
        backing = FixedTextLengthCounter(
            contextSize: contextSize,
            defaultLength: defaultLength,
            counts: counts
        )
        self.promptScale = promptScale
        self.instructionsLength = instructionsLength
    }

    var contextSize: Int {
        backing.contextSize
    }

    func tokenCount(forPrompt text: String) async throws -> Int {
        if promptScale == 1.0 {
            return backing.length(of: text)
        }
        return Int(ceil(
            Double(HeuristicTextLengthCounter.estimatedTokenCount(for: text)) * promptScale
        ))
    }

    func tokenCount(forInstructions text: String) async throws -> Int {
        if let instructionsLength {
            return instructionsLength
        }
        return backing.length(of: text)
    }
}
