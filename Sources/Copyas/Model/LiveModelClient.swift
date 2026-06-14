import Foundation
import FoundationModels

public struct LiveModelClient: ModelClient {
    public init() {}

    public func checkAvailability() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case .unavailable(.deviceNotEligible):
            throw GenerationError.deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            throw GenerationError.appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            throw GenerationError.modelNotReady
        case .unavailable:
            throw GenerationError.modelUnavailable
        }
    }

    public func generate(
        transform: Transform,
        input: String,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        do {
            let session = makeSession(transform: transform)
            if let onPartial {
                return try await generateStreaming(
                    session: session,
                    input: input,
                    onPartial: onPartial
                )
            }
            let response = try await session.respond(to: input)
            return try TransformOutput.parse(response.content)
        } catch {
            throw FoundationModelsErrorMapper.map(error)
        }
    }

    public func prewarm(transform: Transform) {
        makeSession(transform: transform).prewarm()
    }

    public func prewarmAllTransforms() {
        for transform in Transform.allCases {
            prewarm(transform: transform)
        }
    }

    private func makeSession(transform: Transform) -> LanguageModelSession {
        LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: transform.instructions
        )
    }

    private func generateStreaming(
        session: LanguageModelSession,
        input: String,
        onPartial: @Sendable (String) -> Void
    ) async throws -> String {
        let stream = session.streamResponse(to: input)
        var previousLength = 0
        for try await snapshot in stream {
            let content = snapshot.content
            guard content.count > previousLength else { continue }
            let delta = String(content.dropFirst(previousLength))
            previousLength = content.count
            onPartial(delta)
        }
        let response = try await stream.collect()
        return try TransformOutput.parse(response.content)
    }
}
