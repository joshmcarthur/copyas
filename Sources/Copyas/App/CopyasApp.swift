import ArgumentParser
import Foundation

public enum CopyasApp {
    public static func run(environment: AppEnvironment) async -> Int32 {
        do {
            let arguments = environment.arguments.map { $0 == "-v" ? "--version" : $0 }
            let command = try CopyasCommand.parse(arguments)
            let options = command.options

            guard let transform = Transform.named(options.transform) else {
                throw GenerationError.unknownTransform(options.transform)
            }

            let configuration = TransformExecutor.Configuration(
                readsStdin: options.readsStdin,
                writesClipboard: options.writesClipboard,
                streamsToStdout: !options.writesClipboard && !options.noStream
            )
            _ = try await TransformExecutor.run(
                transform: transform,
                configuration: configuration,
                environment: environment
            )
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
