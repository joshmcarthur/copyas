import ArgumentParser
import Foundation

public enum CopyasApp {
    public static func run(environment: AppEnvironment) async -> Int32 {
        do {
            let command = try CopyasCommand.parse(environment.arguments)
            let options = command.options

            if options.showsVersion {
                environment.writeStdout("copyas 0.1.0\n")
                return 0
            }

            _ = try options.requiredTransformName()
            return 0
        } catch let error as GenerationError {
            environment.writeStderr("\(error.message)\n")
            return error.exitCode
        } catch {
            let message = CopyasCommand.fullMessage(for: error)
            let exitCode = CopyasCommand.exitCode(for: error).rawValue
            if !message.isEmpty {
                if exitCode == ExitCode.success.rawValue {
                    let output = message.hasSuffix("\n") ? message : "\(message)\n"
                    environment.writeStdout(output)
                } else {
                    let output = message.hasSuffix("\n") ? message : "\(message)\n"
                    environment.writeStderr(output)
                }
            }
            return exitCode
        }
    }
}
