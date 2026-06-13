import Foundation

public struct AppEnvironment {
    var arguments: [String]
    var inputSource: @Sendable (Bool) -> InputSource
    var writeStdout: (String) -> Void
    var writeStderr: (String) -> Void

    public init(
        arguments: [String],
        inputSource: @escaping @Sendable (Bool) -> InputSource,
        writeStdout: @escaping (String) -> Void,
        writeStderr: @escaping (String) -> Void
    ) {
        self.arguments = arguments
        self.inputSource = inputSource
        self.writeStdout = writeStdout
        self.writeStderr = writeStderr
    }
}
