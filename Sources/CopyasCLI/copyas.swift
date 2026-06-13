import Copyas
import Darwin
import Foundation

@main
struct CopyasCLI {
    static func main() async {
        let environment = AppEnvironment(
            arguments: Array(CommandLine.arguments.dropFirst()),
            writeStdout: { text in
                FileHandle.standardOutput.write(Data(text.utf8))
            },
            writeStderr: { text in
                FileHandle.standardError.write(Data(text.utf8))
            }
        )

        let exitCode = await CopyasApp.run(environment: environment)
        Darwin.exit(exitCode)
    }
}
