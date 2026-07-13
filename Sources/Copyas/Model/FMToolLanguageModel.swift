#if COPYAS_ENABLE_PCC
import Foundation
import FoundationModels

/// A Foundation Models language model that delegates generation to `/usr/bin/fm`.
///
/// Intended for unsandboxed macOS apps. The `fm` command-line tool is outside an app
/// sandbox and is not available to sandboxed processes.
struct FMToolLanguageModel: LanguageModel {
    /// The model selected by the `fm` command-line tool.
    enum Model: String, Hashable {
        /// The Apple Foundation Model hosted by Private Cloud Compute.
        case privateCloudCompute = "pcc"

        /// The on-device Apple Foundation Model.
        case system
    }

    let capabilities = LanguageModelCapabilities([.guidedGeneration])
    let executorConfiguration: Executor.Configuration

    init(
        model: Model = .privateCloudCompute,
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/fm")
    ) {
        executorConfiguration = Executor.Configuration(
            model: model,
            executableURL: executableURL
        )
    }

    struct Executor: LanguageModelExecutor {
        struct Configuration: Hashable {
            var model: Model
            var executableURL: URL

            init(
                model: Model = .privateCloudCompute,
                executableURL: URL = URL(fileURLWithPath: "/usr/bin/fm")
            ) {
                self.model = model
                self.executableURL = executableURL
            }
        }

        private let configuration: Configuration

        init(configuration: Configuration) throws {
            guard FileManager.default.isExecutableFile(
                atPath: configuration.executableURL.path
            ) else {
                throw FMToolLanguageModelError.executableNotFound(
                    configuration.executableURL
                )
            }

            self.configuration = configuration
        }

        func respond(
            to request: LanguageModelExecutorGenerationRequest,
            model _: FMToolLanguageModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
            guard request.enabledToolDefinitions.isEmpty else {
                throw LanguageModelError.unsupportedCapability(
                    .init(
                        capability: .toolCalling,
                        debugDescription: "The fm command-line tool does not support tool calling."
                    )
                )
            }

            let invocation = try Invocation(
                request: request,
                configuration: configuration
            )
            let result = try await invocation.run()

            guard let response = String(data: result.standardOutput, encoding: .utf8) else {
                throw FMToolLanguageModelError.invalidUTF8Output
            }

            guard result.status == 0 else {
                let message = [result.standardError, response]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                throw FMToolLanguageModelError.processFailed(
                    status: result.status,
                    message: message.removingANSIEscapeSequences()
                )
            }

            await channel.send(
                .response(
                    action: .appendText(
                        response.removingOneTrailingNewline(),
                        tokenCount: 0
                    )
                )
            )
        }
    }
}

enum FMToolLanguageModelError: Error, LocalizedError {
    case executableNotFound(URL)
    case invalidRequest(String)
    case invalidUTF8Output
    case processFailed(status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case let .executableNotFound(url):
            "No executable was found at \(url.path)."
        case let .invalidRequest(reason):
            "The request cannot be represented by the fm command-line tool: \(reason)"
        case .invalidUTF8Output:
            "The fm command-line tool returned output that is not valid UTF-8."
        case let .processFailed(status, message):
            "The fm command-line tool exited with status \(status): \(message)"
        }
    }
}

private struct Invocation {
    private struct TranscriptFile: Encodable {
        let transcript: Transcript
    }

    private let executableURL: URL
    private let arguments: [String]
    private let temporaryDirectory: URL
    private let standardOutputURL: URL
    private let standardErrorURL: URL

    init(
        request: LanguageModelExecutorGenerationRequest,
        configuration: FMToolLanguageModel.Executor.Configuration
    ) throws {
        guard case let .prompt(prompt) = request.transcript.last else {
            throw FMToolLanguageModelError.invalidRequest(
                "the transcript must end with a prompt"
            )
        }

        guard !prompt.segments.isEmpty else {
            throw FMToolLanguageModelError.invalidRequest("the prompt is empty")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("copyas-fm-\(request.id.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        var arguments = [
            "respond",
            "--model", configuration.model.rawValue,
            "--no-stream",
        ]

        let history = Transcript(entries: request.transcript.dropLast())
        if !history.isEmpty {
            let transcriptURL = directory.appendingPathComponent("transcript.json")
            let data = try JSONEncoder().encode(TranscriptFile(transcript: history))
            try data.write(to: transcriptURL, options: .atomic)
            arguments += ["--load-transcript", transcriptURL.path]
        }

        for segment in prompt.segments {
            switch segment {
            case let .text(text):
                arguments.append("--text=\(text.content)")
            case .structure:
                throw FMToolLanguageModelError.invalidRequest(
                    "structured prompt segments are unsupported"
                )
            case .attachment:
                throw FMToolLanguageModelError.invalidRequest(
                    "image prompt segments are not yet supported"
                )
            case .custom:
                throw FMToolLanguageModelError.invalidRequest(
                    "custom prompt segments are unsupported"
                )
            @unknown default:
                throw FMToolLanguageModelError.invalidRequest(
                    "the prompt contains an unknown segment type"
                )
            }
        }

        if let schema = request.schema {
            let schemaURL = directory.appendingPathComponent("schema.json")
            let data = try JSONEncoder().encode(schema)
            try data.write(to: schemaURL, options: .atomic)
            arguments += ["--schema", schemaURL.path]
        }

        if request.generationOptions.samplingMode?.kind == .greedy {
            arguments.append("--greedy")
        }

        executableURL = configuration.executableURL
        self.arguments = arguments
        temporaryDirectory = directory
        standardOutputURL = directory.appendingPathComponent("stdout")
        standardErrorURL = directory.appendingPathComponent("stderr")
    }

    func run() async throws -> CommandResult {
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        FileManager.default.createFile(
            atPath: standardOutputURL.path,
            contents: nil
        )
        FileManager.default.createFile(
            atPath: standardErrorURL.path,
            contents: nil
        )

        let standardOutput = try FileHandle(forWritingTo: standardOutputURL)
        let standardError = try FileHandle(forWritingTo: standardErrorURL)
        defer {
            try? standardOutput.close()
            try? standardError.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = [
            "-q", "/dev/null",
            "/bin/sh", "-c",
            "stty rows 24 cols 80; exec \"$@\"",
            "copyas-fm",
            executableURL.path,
        ] + arguments

        let standardInput = Pipe()
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError
        defer {
            try? standardInput.fileHandleForWriting.close()
            try? standardInput.fileHandleForReading.close()
        }

        let status = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Int32, any Error>) in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }

        try standardOutput.synchronize()
        try standardError.synchronize()

        return try CommandResult(
            status: status,
            standardOutput: Data(contentsOf: standardOutputURL),
            standardErrorData: Data(contentsOf: standardErrorURL)
        )
    }
}

private struct CommandResult {
    let status: Int32
    let standardOutput: Data
    let standardError: String

    init(status: Int32, standardOutput: Data, standardErrorData: Data) throws {
        guard let standardError = String(data: standardErrorData, encoding: .utf8) else {
            throw FMToolLanguageModelError.invalidUTF8Output
        }

        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

private extension String {
    func removingOneTrailingNewline() -> String {
        if hasSuffix("\r\n") {
            return String(dropLast())
        }
        if hasSuffix("\n") {
            return String(dropLast())
        }
        return self
    }

    func removingANSIEscapeSequences() -> String {
        replacing(
            /\u{001B}\[[0-?]*[ -\/]*[@-~]/,
            with: ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
