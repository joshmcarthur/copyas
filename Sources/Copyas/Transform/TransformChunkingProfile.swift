import Foundation
import RecursiveTextSplit

public struct TransformChunkingProfile: Sendable, Equatable {
    public enum Mode: Sendable, Equatable {
        case stuff
        case mapOnly
        case mapReduce
    }

    public enum MergeStrategy: Sendable, Equatable {
        case concatenate(separator: String)
        case reduce(instructions: String)
    }

    public struct SplitSettings: Sendable, Equatable {
        public var separators: [String]
        public var overlapTokens: Int
        public var minChunkLength: Int

        public init(
            separators: [String] = SplitConfig.langchainDefaultSeparators,
            overlapTokens: Int = 0,
            minChunkLength: Int = 1
        ) {
            self.separators = separators
            self.overlapTokens = overlapTokens
            self.minChunkLength = minChunkLength
        }

        public static let langchainDefault = SplitSettings()

        public func makeConfig(chunkSize: Int) -> SplitConfig {
            SplitConfig(
                separators: separators,
                chunkSize: chunkSize,
                chunkOverlap: overlapTokens,
                keepSeparator: true,
                minChunkLength: minChunkLength
            )
        }
    }

    public let mode: Mode
    public let split: SplitSettings
    public let merge: MergeStrategy
    public let outputTokenReserve: Int
    public let maxReduceDepth: Int

    public init(
        mode: Mode,
        split: SplitSettings = .langchainDefault,
        merge: MergeStrategy,
        outputTokenReserve: Int,
        maxReduceDepth: Int = 3
    ) {
        self.mode = mode
        self.split = split
        self.merge = merge
        self.outputTokenReserve = outputTokenReserve
        self.maxReduceDepth = maxReduceDepth
    }
}

extension Transform {
    private static let summaryReduceInstructions = """
    Merge the following bullet lists into one concise list. Use `-` for bullets. Deduplicate overlapping points. Preserve factual accuracy. Do not add information that is not in the source. Output only the merged summary, no preamble.
    """

    public var chunkingProfile: TransformChunkingProfile {
        switch self {
        case .pirate:
            TransformChunkingProfile(
                mode: .mapOnly,
                merge: .concatenate(separator: "\n\n"),
                outputTokenReserve: 800
            )
        case .markdown:
            TransformChunkingProfile(
                mode: .mapOnly,
                merge: .concatenate(separator: "\n\n"),
                outputTokenReserve: 1200
            )
        case .summary:
            TransformChunkingProfile(
                mode: .mapReduce,
                merge: .reduce(instructions: Self.summaryReduceInstructions),
                outputTokenReserve: 400,
                maxReduceDepth: 3
            )
        }
    }
}
