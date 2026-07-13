import Foundation
import FoundationModels

/// A Foundation Models language model that delegates generation to `/usr/bin/fm`.
///
/// `FMToolLanguageModel` is intended for unsandboxed macOS apps. The command-line
/// tool is outside an app sandbox and is not available to sandboxed processes.
public struct FMToolLanguageModel: LanguageModel {
    /// The model selected by the `fm` command-line tool.
    public enum Model: String, Hashable, Sendable {
        /// The Apple Foundation Model hosted by Private Cloud Compute.
        case privateCloudCompute = "pcc"

        /// The on-device Apple Foundation Model.
        case system
    }

    public let capabilities = LanguageModelCapabilities([.guidedGeneration])
    public let executorConfiguration: Executor.Configuration

    /// Creates an `fm`-backed model.
    ///
    /// - Parameters:
    ///   - model: The model for `fm` to use. Defaults to Private Cloud Compute.
    ///   - executableURL: The location of the `fm` executable.
    public init(
        model: Model = .privateCloudCompute,
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/fm")
    ) {
        executorConfiguration = Executor.Configuration(
            model: model,
            executableURL: executableURL
        )
    }

    public struct Executor: LanguageModelExecutor {
        public struct Configuration: Hashable, Sendable {
            public var model: Model
            public var executableURL: URL

            public init(
                model: Model = .privateCloudCompute,
                executableURL: URL = URL(fileURLWithPath: "/usr/bin/fm")
            ) {
                self.model = model
                self.executableURL = executableURL
            }
        }

        private let configuration: Configuration

        public init(configuration: Configuration) throws {
            guard FileManager.default.isExecutableFile(
                atPath: configuration.executableURL.path
            ) else {
                throw FMToolLanguageModelError.executableNotFound(
                    configuration.executableURL
                )
            }

            self.configuration = configuration
        }

        public func respond(
            to request: LanguageModelExecutorGenerationRequest,
            model: FMToolLanguageModel,
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

public enum FMToolLanguageModelError: Error, LocalizedError, Sendable {
    case executableNotFound(URL)
    case invalidRequest(String)
    case invalidUTF8Output
    case processFailed(status: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let url):
            "No executable was found at \(url.path)."
        case .invalidRequest(let reason):
            "The request cannot be represented by the fm command-line tool: \(reason)"
        case .invalidUTF8Output:
            "The fm command-line tool returned output that is not valid UTF-8."
        case .processFailed(let status, let message):
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
        guard case .prompt(let prompt) = request.transcript.last else {
            throw FMToolLanguageModelError.invalidRequest(
                "the transcript must end with a prompt"
            )
        }

        guard !prompt.segments.isEmpty else {
            throw FMToolLanguageModelError.invalidRequest("the prompt is empty")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TwoMillionKit-\(request.id.uuidString)", isDirectory: true)
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
            case .text(let text):
                // Keep the option and its value in one argv element so content
                // beginning with "--" cannot be interpreted as another option.
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

        self.executableURL = configuration.executableURL
        self.arguments = arguments
        self.temporaryDirectory = directory
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

        // PCC's command-line access gate requires a controlling terminal with a
        // nonzero window size. Apple's script(1) provides the signed process
        // boundary and PTY that fm expects. User-provided arguments are passed
        // positionally through "$@" and are never interpolated into shell code.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = [
            "-q", "/dev/null",
            "/bin/sh", "-c",
            "stty rows 24 cols 80; exec \"$@\"",
            "TwoMillionKit-fm",
            executableURL.path,
        ] + arguments

        // Keep stdin open until the child exits. Closing it causes script(1) to
        // render an EOF marker into the captured terminal output.
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

private struct CommandResult: Sendable {
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
            // Swift treats CRLF as one extended grapheme cluster.
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
