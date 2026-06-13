import Foundation

public struct AppEnvironment {
    var arguments: [String]
    var writeStdout: (String) -> Void
    var writeStderr: (String) -> Void

    public init(
        arguments: [String],
        writeStdout: @escaping (String) -> Void,
        writeStderr: @escaping (String) -> Void
    ) {
        self.arguments = arguments
        self.writeStdout = writeStdout
        self.writeStderr = writeStderr
    }
}
