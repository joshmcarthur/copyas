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

            let transformName = try options.requiredTransformName()
            guard let transform = TransformRegistry.resolve(transformName) else {
                throw GenerationError.unknownTransform(transformName)
            }

            let input = try environment.inputSource(options.readsClipboard).readText()
            try environment.modelClient.checkAvailability()
            let output = try await environment.modelClient.generate(
                transform: transform,
                input: input
            )
            environment.writeStdout(output.hasSuffix("\n") ? output : "\(output)\n")
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
