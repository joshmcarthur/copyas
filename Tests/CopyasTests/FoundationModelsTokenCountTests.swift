@testable import Copyas
import FoundationModels
import XCTest

/// Optional live smoke tests against `SystemLanguageModel.tokenCount`.
///
/// Budget and split logic is covered without FM in `TokenBudgetTests` via `StubAsyncTokenCounter`
/// and `FixedTextLengthCounter` / `HeuristicTextLengthCounter` (both conform to
/// `AsyncTokenCounter`).
/// These tests only run when Apple Intelligence is enabled on the host.
final class FoundationModelsTokenCountTests: XCTestCase {
    func testContextSizeIs4096() throws {
        let model = try FoundationModelsTestSupport.requireAvailableModel()
        XCTAssertEqual(model.contextSize, 4096)
    }

    @available(macOS 26.4, *)
    func testTokenCountAPIAvailableOnSupportedOS() async throws {
        let model = try await FoundationModelsTestSupport.requireTokenCounting()
        let count = try await model.tokenCount(for: "hello")
        XCTAssertGreaterThan(count, 0)
    }

    @available(macOS 26.4, *)
    func testInstructionsCountUsesInstructionsAPI() async throws {
        let model = try await FoundationModelsTestSupport.requireTokenCounting()
        let text = Transform.summary.instructions
        let asPrompt = try await model.tokenCount(for: text)
        let asInstructions = try await model.tokenCount(for: Instructions(text))
        XCTAssertGreaterThan(asPrompt, 0)
        XCTAssertGreaterThan(asInstructions, 0)
    }

    @available(macOS 26.4, *)
    func testLiveCounterMatchesHeuristicBallpark() async throws {
        let model = try await FoundationModelsTestSupport.requireTokenCounting()
        let counter = FoundationModelsTokenCounter(model: model)

        let pirateInstructions = Transform.pirate.instructions
        let heuristicInstructions = HeuristicTextLengthCounter
            .estimatedTokenCount(for: pirateInstructions)
        let fmInstructions = try await counter.tokenCount(forInstructions: pirateInstructions)
        XCTAssertGreaterThan(fmInstructions, 0)
        XCTAssertLessThan(
            abs(Double(fmInstructions) / Double(heuristicInstructions) - 1.0),
            2.0,
            "FM instructions=\(fmInstructions) heuristic=\(heuristicInstructions)"
        )
    }
}
