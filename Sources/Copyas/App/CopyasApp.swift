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

            let input = try environment.makeInputSource(options.readsStdin).readText()
            try InputSuitability.validate(input)
            try environment.modelClient.checkAvailability()
            let sink = environment.makeOutputSink(options.writesClipboard)
            let useStreaming = !options.writesClipboard && !options.noStream
            if useStreaming {
                let output = try await environment.modelClient.generate(
                    transform: transform,
                    input: input,
                    onPartial: { sink.writePartial($0) }
                )
                try sink.finalize(output)
            } else {
                let output = try await environment.modelClient.generate(
                    transform: transform,
                    input: input,
                    onPartial: nil
                )
                try sink.write(output)
            }
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
