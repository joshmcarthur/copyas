import Foundation
import FoundationModels

public struct LiveModelClient: ModelClient {
    private let budget: TokenBudget

    public init(budget: TokenBudget = TokenBudget()) {
        self.budget = budget
    }

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
            let profile = transform.chunkingProfile
            if try await budget.fitsInOnePass(
                profile: profile,
                instructions: transform.instructions,
                input: input
            ) {
                return try await generateSinglePass(
                    instructions: transform.instructions,
                    input: input,
                    onPartial: onPartial
                )
            }
            return try await ChunkedGenerator.generate(
                profile: profile,
                mapInstructions: transform.instructions,
                input: input,
                budget: budget,
                onPartial: onPartial,
                generateChunk: { instructions, chunk, partial in
                    try await generateSinglePass(
                        instructions: instructions,
                        input: chunk,
                        onPartial: partial
                    )
                }
            )
        } catch {
            throw FoundationModelsErrorMapper.map(error)
        }
    }

    public func prewarm(transform: Transform) {
        makeSession(instructions: transform.instructions).prewarm()
    }

    public func prewarmAllTransforms() {
        for transform in Transform.allCases {
            prewarm(transform: transform)
        }
    }

    private func generateSinglePass(
        instructions: String,
        input: String,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        let session = makeSession(instructions: instructions)
        if let onPartial {
            return try await generateStreaming(
                session: session,
                input: input,
                onPartial: onPartial
            )
        }
        let response = try await session.respond(to: input)
        return try TransformOutput.parse(response.content)
    }

    private func makeSession(instructions: String) -> LanguageModelSession {
        LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: instructions
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
