import ArgumentParser
import Foundation

struct CopyasOptions: ParsableArguments {
    @Argument(help: "Transform to apply: summary, markdown, pirate.")
    var transform: String

    @Flag(name: .customLong("stdin"), help: "Read from stdin instead of the clipboard.")
    var readsStdin = false

    @Flag(
        name: [.customShort("w"), .customLong("write")],
        help: "Write the result to the clipboard instead of stdout."
    )
    var writesClipboard = false

    @Flag(
        name: .customLong("no-stream"),
        help: "Buffer the full response before writing to stdout."
    )
    var noStream = false
}

struct CopyasCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: CopyasMetadata.name,
        abstract: """
        Transform clipboard text and stream the result to stdout by default, \
        or write back to the clipboard with --write.
        """,
        version: CopyasMetadata.version
    )

    @OptionGroup
    var options: CopyasOptions
}
