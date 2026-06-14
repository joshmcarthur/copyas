import Foundation

public enum TransformExecutor {
    public struct Configuration: Sendable {
        public var readsStdin: Bool
        public var writesClipboard: Bool
        public var streamsToStdout: Bool

        public static let clipboardOnly = Configuration(
            readsStdin: false,
            writesClipboard: true,
            streamsToStdout: false
        )
    }

    @discardableResult
    public static func run(
        transform: Transform,
        configuration: Configuration,
        environment: AppEnvironment
    ) async throws -> String {
        let input = try environment.makeInputSource(configuration.readsStdin).readText()
        try InputSuitability.validate(input)
        try environment.modelClient.checkAvailability()
        let sink = environment.makeOutputSink(configuration.writesClipboard)
        if configuration.streamsToStdout {
            let output = try await environment.modelClient.generate(
                transform: transform,
                input: input,
                onPartial: { sink.writePartial($0) }
            )
            try sink.finalize(output)
            return output
        }
        let output = try await environment.modelClient.generate(
            transform: transform,
            input: input,
            onPartial: nil
        )
        try sink.write(output)
        return output
    }
}
