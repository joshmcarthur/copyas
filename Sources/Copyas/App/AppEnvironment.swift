import Foundation

public struct AppEnvironment: Sendable {
    var arguments: [String]
    var makeInputSource: @Sendable (Bool) -> InputSource
    var modelClient: any ModelClient
    var writeStdout: @Sendable (String) -> Void
    var writeStderr: @Sendable (String) -> Void

    public init(
        arguments: [String],
        makeInputSource: @escaping @Sendable (Bool) -> InputSource,
        modelClient: any ModelClient,
        writeStdout: @escaping @Sendable (String) -> Void,
        writeStderr: @escaping @Sendable (String) -> Void
    ) {
        self.arguments = arguments
        self.makeInputSource = makeInputSource
        self.modelClient = modelClient
        self.writeStdout = writeStdout
        self.writeStderr = writeStderr
    }
}
