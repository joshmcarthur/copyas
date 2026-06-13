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

    @Flag(name: [.customShort("v"), .customLong("version")], help: "Show version.")
    var showsVersion = false

    func requiredTransformName() throws -> String {
        if showsVersion {
            return ""
        }

        guard let transformName, !transformName.isEmpty else {
            throw GenerationError.missingTransform
        }

        return transformName
    }
}

struct CopyasCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "copyas",
        abstract: "Read text, apply a named transform, and write the result to stdout.",
        version: "0.1.0"
    )

    @OptionGroup
    var options: CopyasOptions
}
