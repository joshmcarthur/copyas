import Foundation

public struct AppEnvironment {
    var writeStdout: (String) -> Void
    var writeStderr: (String) -> Void

    public init(
        writeStdout: @escaping (String) -> Void,
        writeStderr: @escaping (String) -> Void
    ) {
        self.writeStdout = writeStdout
        self.writeStderr = writeStderr
    }
}
