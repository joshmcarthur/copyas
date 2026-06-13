import ArgumentParser
import Foundation

public enum CopyasApp {
    public static func run(environment: AppEnvironment) async -> Int32 {
        do {
            let arguments = environment.arguments.map { $0 == "-v" ? "--version" : $0 }
            let command = try CopyasCommand.parse(arguments)
            let options = command.options

            guard let transformName = options.transformName, !transformName.isEmpty else {
                throw GenerationError.missingTransform
            }
            guard let transform = Transform.named(transformName) else {
                throw GenerationError.unknownTransform(transformName)
            }

            let input = try environment.makeInputSource(options.readsClipboard).readText()
            try InputSuitability.validate(input)
            try environment.modelClient.checkAvailability()
            let output = try await environment.modelClient.generate(
                transform: transform,
                input: input
            )
            writeln(output, to: .stdout, via: environment)
            return 0
        } catch {
            return handleExit(error, environment: environment)
        }
    }
}

private enum OutputStream {
    case stdout
    case stderr
}

private func writeln(_ text: String, to stream: OutputStream, via environment: AppEnvironment) {
    let line = text.hasSuffix("\n") ? text : "\(text)\n"
    switch stream {
    case .stdout:
        environment.writeStdout(line)
    case .stderr:
        environment.writeStderr(line)
    }
}

private func handleExit(_ error: Error, environment: AppEnvironment) -> Int32 {
    if let error = error as? GenerationError {
        writeln(error.message, to: .stderr, via: environment)
        return error.exitCode
    }
    let message = CopyasCommand.fullMessage(for: error)
    let exitCode = CopyasCommand.exitCode(for: error).rawValue
    if !message.isEmpty {
        let stream: OutputStream = exitCode == ExitCode.success.rawValue ? .stdout : .stderr
        writeln(message, to: stream, via: environment)
    }
    return exitCode
}
