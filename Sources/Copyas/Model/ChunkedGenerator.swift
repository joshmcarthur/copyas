import Foundation
import RecursiveTextSplit

enum ChunkedGenerator {
    typealias GenerateChunk = @Sendable (
        _ instructions: String,
        _ chunk: String,
        _ onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String

    static func generate(
        profile: TransformChunkingProfile,
        mapInstructions: String,
        input: String,
        budget: some ChunkingBudget,
        onPartial: (@Sendable (String) -> Void)?,
        generateChunk: GenerateChunk
    ) async throws -> String {
        switch profile.mode {
        case .stuff:
            try await generateChunk(mapInstructions, input, onPartial)
        case .mapOnly:
            try await generateMapOnly(
                profile: profile,
                mapInstructions: mapInstructions,
                input: input,
                budget: budget,
                onPartial: onPartial,
                generateChunk: generateChunk
            )
        case .mapReduce:
            try await generateMapReduce(
                profile: profile,
                mapInstructions: mapInstructions,
                input: input,
                budget: budget,
                onPartial: onPartial,
                generateChunk: generateChunk
            )
        }
    }

    private static func generateMapOnly(
        profile: TransformChunkingProfile,
        mapInstructions: String,
        input: String,
        budget: some ChunkingBudget,
        onPartial: (@Sendable (String) -> Void)?,
        generateChunk: GenerateChunk
    ) async throws -> String {
        let chunks = try await budget.split(
            profile: profile,
            instructions: mapInstructions,
            input: input
        )
        var outputs: [String] = []
        for chunk in chunks {
            let output = try await generateChunk(mapInstructions, chunk, onPartial)
            outputs.append(output)
        }
        guard case let .concatenate(separator) = profile.merge else {
            throw GenerationError.generationFailed("invalid merge strategy for map-only transform")
        }
        return outputs.joined(separator: separator)
    }

    private static func generateMapReduce(
        profile: TransformChunkingProfile,
        mapInstructions: String,
        input: String,
        budget: some ChunkingBudget,
        onPartial: (@Sendable (String) -> Void)?,
        generateChunk: GenerateChunk
    ) async throws -> String {
        let chunks = try await budget.split(
            profile: profile,
            instructions: mapInstructions,
            input: input
        )
        var partials: [String] = []
        for chunk in chunks {
            let summary = try await generateChunk(mapInstructions, chunk, onPartial)
            partials.append(summary)
        }
        return try await reducePartials(
            profile: profile,
            partials: partials,
            budget: budget,
            depth: 0,
            onPartial: onPartial,
            generateChunk: generateChunk
        )
    }

    private static func reducePartials(
        profile: TransformChunkingProfile,
        partials: [String],
        budget: some ChunkingBudget,
        depth: Int,
        onPartial: (@Sendable (String) -> Void)?,
        generateChunk: GenerateChunk
    ) async throws -> String {
        guard case let .reduce(reduceInstructions) = profile.merge else {
            throw GenerationError
                .generationFailed("invalid merge strategy for map-reduce transform")
        }

        let combined = partials.joined(separator: "\n\n")
        if try await budget.fitsInBudget(
            instructions: reduceInstructions,
            input: combined,
            outputReserve: profile.outputTokenReserve
        ) {
            return try await generateChunk(reduceInstructions, combined, onPartial)
        }

        guard depth < profile.maxReduceDepth else {
            throw GenerationError.contextWindowExceeded
        }

        let collapseProfile = TransformChunkingProfile(
            mode: .mapReduce,
            merge: profile.merge,
            outputTokenReserve: profile.outputTokenReserve,
            maxReduceDepth: profile.maxReduceDepth
        )
        let collapseChunks = try await budget.split(
            profile: collapseProfile,
            instructions: reduceInstructions,
            input: combined
        )
        var collapsed: [String] = []
        for chunk in collapseChunks {
            let summary = try await generateChunk(reduceInstructions, chunk, onPartial)
            collapsed.append(summary)
        }
        return try await reducePartials(
            profile: profile,
            partials: collapsed,
            budget: budget,
            depth: depth + 1,
            onPartial: onPartial,
            generateChunk: generateChunk
        )
    }
}
