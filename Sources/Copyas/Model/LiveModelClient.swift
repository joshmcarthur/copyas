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

    public func generate(transform: Transform, input: String) async throws -> String {
        do {
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: transform.instructions
            )
            let response = try await session.respond(to: input)
            return try TransformOutput.parse(response.content)
        } catch {
            throw FoundationModelsErrorMapper.map(error)
        }
    }
}
