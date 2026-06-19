import Foundation

public struct SplitConfig: Sendable, Equatable {
    public static let langchainDefaultSeparators = ["\n\n", "\n", " ", ""]
    public static let langchainCJKSeparators = [
        "\n\n", "\n", " ", ".", ",", "\u{200b}", "\u{ff0c}", "\u{3001}", "\u{ff0e}", "\u{3002}", "",
    ]

    public var separators: [String]
    public var chunkSize: Int
    public var chunkOverlap: Int
    public var keepSeparator: Bool
    public var minChunkLength: Int

    public init(
        separators: [String] = SplitConfig.langchainDefaultSeparators,
        chunkSize: Int,
        chunkOverlap: Int = 0,
        keepSeparator: Bool = true,
        minChunkLength: Int = 1
    ) {
        self.separators = separators
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.keepSeparator = keepSeparator
        self.minChunkLength = minChunkLength
    }

    public static func langchainDefault(chunkSize: Int, chunkOverlap: Int = 0) -> SplitConfig {
        SplitConfig(
            separators: langchainDefaultSeparators,
            chunkSize: chunkSize,
            chunkOverlap: chunkOverlap
        )
    }

    public static func langchainCJK(chunkSize: Int, chunkOverlap: Int = 0) -> SplitConfig {
        SplitConfig(
            separators: langchainCJKSeparators,
            chunkSize: chunkSize,
            chunkOverlap: chunkOverlap
        )
    }

    public func with(chunkSize: Int) -> SplitConfig {
        var copy = self
        copy.chunkSize = chunkSize
        return copy
    }
}
