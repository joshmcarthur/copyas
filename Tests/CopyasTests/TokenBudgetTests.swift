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

    func testAsyncBudgetFitsInOnePass() async throws {
        let budget = TokenBudget()
        let profile = Transform.pirate.chunkingProfile
        let fits = try await budget.fitsInOnePass(
            profile: profile,
            instructions: "brief",
            input: "short text"
        )
        XCTAssertTrue(fits)
    }

    func testAsyncBudgetDetectsLongInputNeedsChunking() async throws {
        let budget = TokenBudget()
        let profile = Transform.pirate.chunkingProfile
        let input = String(repeating: "word ", count: 10000)
        let fits = try await budget.fitsInOnePass(
            profile: profile,
            instructions: Transform.pirate.instructions,
            input: input
        )
        XCTAssertFalse(fits)
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

    func testAsyncFitsInBudget() async throws {
        let budget = TokenBudget()
        let fits = try await budget.fitsInBudget(
            instructions: "brief",
            input: "short",
            outputReserve: 50
        )
        XCTAssertTrue(fits)
    }
}
