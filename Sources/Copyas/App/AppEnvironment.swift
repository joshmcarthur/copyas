import Foundation

public struct AppEnvironment: Sendable {
    var arguments: [String]
    var inputSource: @Sendable (Bool) -> InputSource
    var modelClient: any ModelClient
    var writeStdout: @Sendable (String) -> Void
    var writeStderr: @Sendable (String) -> Void

    public init(
        arguments: [String],
        inputSource: @escaping @Sendable (Bool) -> InputSource,
        modelClient: any ModelClient,
        writeStdout: @escaping @Sendable (String) -> Void,
        writeStderr: @escaping @Sendable (String) -> Void
    ) {
        self.arguments = arguments
        self.inputSource = inputSource
        self.modelClient = modelClient
        self.writeStdout = writeStdout
        self.writeStderr = writeStderr
    }
}
