import Foundation
import FoundationModels

public struct LiveModelClient: ModelClient {
    private let backend: ModelBackend
    private let budget: TokenBudget

    public init(backend: ModelBackend) {
        self.backend = backend
        budget = TokenBudget(tokenCounter: backend.makeTokenCounter())
    }

    public init(preference: ModelPreference = .automatic) throws {
        try self.init(backend: ModelResolver.resolve(preference: preference))
    }

    public init() {
        let backend = (try? ModelResolver.resolve(preference: .automatic)) ?? .onDevice(.default)
        self.init(backend: backend)
    }

    public func checkAvailability() throws {
        switch backend {
        case let .onDevice(model):
            try checkOnDeviceAvailability(model)
        case .privateCloudCompute:
            return
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
        guard case .onDevice = backend else { return }
        makeSession(instructions: transform.instructions).prewarm()
    }

    public func prewarmAllTransforms() {
        for transform in Transform.allCases {
            prewarm(transform: transform)
        }
    }

    private func checkOnDeviceAvailability(_ model: SystemLanguageModel) throws {
        switch model.availability {
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

    private func generateSinglePass(
        instructions: String,
        input: String,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        let session = makeSession(instructions: instructions)
        if let onPartial {
            if backend.supportsStreaming {
                return try await generateStreaming(
                    session: session,
                    input: input,
                    onPartial: onPartial
                )
            }
            let response = try await session.respond(to: input)
            let content = try TransformOutput.parse(response.content)
            onPartial(content)
            return content
        }
        let response = try await session.respond(to: input)
        return try TransformOutput.parse(response.content)
    }

    private func makeSession(instructions: String) -> LanguageModelSession {
        backend.makeSession(instructions: instructions)
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
