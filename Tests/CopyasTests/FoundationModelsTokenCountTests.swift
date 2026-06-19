@testable import Copyas
import FoundationModels
import XCTest

/// Exercises live `SystemLanguageModel.tokenCount` when Apple Intelligence is available.
/// Skips quietly on CI simulators or when the model is unavailable.
final class FoundationModelsTokenCountTests: XCTestCase {
    private func requireAvailableModel() throws -> SystemLanguageModel {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw XCTSkip("SystemLanguageModel unavailable: \(model.availability)")
        }
        return model
    }

    func testContextSizeIs4096() throws {
        let model = try requireAvailableModel()
        XCTAssertEqual(model.contextSize, 4096)
    }

    @available(macOS 26.4, *)
    func testTokenCountAPIAvailableOnSupportedOS() async throws {
        let model = try requireAvailableModel()
        let count = try await model.tokenCount(for: "hello")
        XCTAssertGreaterThan(count, 0)
    }

    @available(macOS 26.4, *)
    func testInstructionsAndPromptCountsDifferFromHeuristic() async throws {
        let model = try requireAvailableModel()
        let counter = FoundationModelsTokenCounter(model: model)

        let pirateInstructions = Transform.pirate.instructions
        let heuristicInstructions = HeuristicTextLengthCounter
            .estimatedTokenCount(for: pirateInstructions)
        let fmInstructions = try await counter.tokenCount(forInstructions: pirateInstructions)
        XCTAssertGreaterThan(fmInstructions, 0)
        // Heuristic should be in the same ballpark (within 3×) for Latin instructions.
        XCTAssertLessThan(
            abs(Double(fmInstructions) / Double(heuristicInstructions) - 1.0),
            2.0,
            "FM instructions=\(fmInstructions) heuristic=\(heuristicInstructions)"
        )

        let input = String(repeating: "word ", count: 500)
        let heuristicInput = HeuristicTextLengthCounter.estimatedTokenCount(for: input)
        let fmInput = try await counter.tokenCount(forPrompt: input)
        XCTAssertGreaterThan(fmInput, 0)
        XCTAssertLessThan(
            abs(Double(fmInput) / Double(heuristicInput) - 1.0),
            2.0,
            "FM input=\(fmInput) heuristic=\(heuristicInput)"
        )
    }

    @available(macOS 26.4, *)
    func testInstructionsCountUsesInstructionsAPI() async throws {
        let model = try requireAvailableModel()
        let text = Transform.summary.instructions
        let asPrompt = try await model.tokenCount(for: text)
        let asInstructions = try await model.tokenCount(for: Instructions(text))
        // Same bytes may tokenize differently by role; we only require both are positive.
        XCTAssertGreaterThan(asPrompt, 0)
        XCTAssertGreaterThan(asInstructions, 0)
    }

    @available(macOS 26.4, *)
    func testLiveBudgetFitsShortInput() async throws {
        _ = try requireAvailableModel()
        let budget = TokenBudget()
        let profile = Transform.pirate.chunkingProfile
        let fits = try await budget.fitsInOnePass(
            profile: profile,
            instructions: Transform.pirate.instructions,
            input: "A short paragraph of text."
        )
        XCTAssertTrue(fits)
    }

    @available(macOS 26.4, *)
    func testLiveBudgetSplitUsesFMValidation() async throws {
        _ = try requireAvailableModel()
        let budget = TokenBudget()
        let profile = Transform.pirate.chunkingProfile
        let input = String(repeating: "Paragraph one.\n\n", count: 800)
        let chunks = try await budget.split(
            profile: profile,
            instructions: Transform.pirate.instructions,
            input: input
        )
        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            let count = try await FoundationModelsTokenCounter().tokenCount(forPrompt: chunk)
            let maxTokens = try await budget.maxInputTokens(
                profile: profile,
                instructions: Transform.pirate.instructions
            )
            XCTAssertLessThanOrEqual(count, maxTokens, "chunk exceeded budget after FM validation")
        }
    }
}
