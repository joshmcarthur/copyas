import Foundation
import RecursiveTextSplit

protocol ChunkingBudget: Sendable {
    func split(
        profile: TransformChunkingProfile,
        instructions: String,
        input: String
    ) async throws -> [String]

    func fitsInBudget(
        instructions: String,
        input: String,
        outputReserve: Int
    ) async throws -> Bool
}

extension TokenBudget: ChunkingBudget {}

extension SynchronousTokenBudget: ChunkingBudget {
    func split(
        profile: TransformChunkingProfile,
        instructions: String,
        input: String
    ) async throws -> [String] {
        try splitSynchronously(profile: profile, instructions: instructions, input: input)
    }

    func fitsInBudget(
        instructions: String,
        input: String,
        outputReserve: Int
    ) async throws -> Bool {
        containsWithinBudget(
            instructions: instructions,
            input: input,
            outputReserve: outputReserve
        )
    }
}
