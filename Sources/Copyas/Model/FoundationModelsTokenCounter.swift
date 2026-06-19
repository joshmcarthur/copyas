import Foundation
import FoundationModels

/// Counts tokens for budgeting. Prefers Foundation Models `tokenCount` on macOS 26.4+.
///
/// Foundation Models exposes separate counting APIs by role:
/// - `tokenCount(for: Instructions)` — system/session instructions (what `LanguageModelSession`
/// uses)
/// - `tokenCount(for: String)` — user prompt content passed to `respond(to:)` /
/// `streamResponse(to:)`
///
/// Both are async and require macOS 26.4+. `contextSize` is available from macOS 26.0
/// (`@backDeployed` before 26.4) and returns 4096 for on-device models.
public struct FoundationModelsTokenCounter: AsyncTokenCounter, Sendable {
    private let model: SystemLanguageModel

    public init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    public var contextSize: Int {
        model.contextSize
    }

    public func tokenCount(forPrompt text: String) async throws -> Int {
        if #available(macOS 26.4, *) {
            return try await model.tokenCount(for: text)
        }
        return HeuristicTextLengthCounter.estimatedTokenCount(for: text)
    }

    public func tokenCount(forInstructions text: String) async throws -> Int {
        if #available(macOS 26.4, *) {
            return try await model.tokenCount(for: Instructions(text))
        }
        return HeuristicTextLengthCounter.estimatedTokenCount(for: text)
    }
}
