import Copyas
import Darwin
import Foundation

@main
struct CopyasCLI {
    nonisolated static func main() async {
        let writeStdout: @Sendable (String) -> Void = { text in
            FileHandle.standardOutput.write(Data(text.utf8))
        }

        let environment = AppEnvironment(
            arguments: Array(CommandLine.arguments.dropFirst()),
            makeInputSource: InputSource.live,
            makeOutputSink: { writesClipboard in
                OutputSink.live(writesClipboard: writesClipboard, writeStdout: writeStdout)
            },
            modelClient: LiveModelClient(),
            writeStdout: writeStdout,
            writeStderr: { text in
                FileHandle.standardError.write(Data(text.utf8))
            }
        )

        let exitCode = await CopyasApp.run(environment: environment)
        Darwin.exit(exitCode)
    }
}
