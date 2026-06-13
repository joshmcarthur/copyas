import ArgumentParser
import Foundation

struct CopyasOptions: ParsableArguments {
    @Option(
        name: [.customShort("t"), .customLong("transform")],
        help: "Transform to apply: summary, markdown, pirate."
    )
    var transformName: String?

    @Flag(
        name: [.customShort("c"), .customLong("clipboard")],
        help: "Read input from the general pasteboard instead of stdin."
    )
    var readsClipboard = false
}

struct CopyasCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: CopyasMetadata.name,
        abstract: "Read text, apply a named transform, and write the result to stdout.",
        version: CopyasMetadata.version
    )

    @OptionGroup
    var options: CopyasOptions
}
