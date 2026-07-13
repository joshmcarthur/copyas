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

    @Flag(
        name: .customLong("cloud"),
        help: "Use Private Cloud Compute via the fm command-line tool."
    )
    var useCloud = false

    @Flag(name: .customLong("local"), help: "Force on-device model only.")
    var useLocal = false

    var modelPreference: ModelPreference {
        if useCloud { return .cloud }
        if useLocal { return .local }
        return .automatic
    }

    func validate() throws {
        if useCloud, useLocal {
            throw ValidationError("Cannot use --cloud and --local together.")
        }
    }
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
