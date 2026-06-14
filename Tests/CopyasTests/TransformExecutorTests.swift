@testable import Copyas
import XCTest

private final class ClipboardCapture: @unchecked Sendable {
    var value = ""
}

private final class CountingModelClient: ModelClient, @unchecked Sendable {
    var output = "generated output"
    var availabilityError: GenerationError?
    private(set) var generateCallCount = 0

    init(availabilityError: GenerationError? = nil) {
        self.availabilityError = availabilityError
    }

    func checkAvailability() throws {
        if let availabilityError {
            throw availabilityError
        }
    }

    func generate(
        transform _: Transform,
        input _: String,
        onPartial _: (@Sendable (String) -> Void)?
    ) async throws -> String {
        generateCallCount += 1
        return output
    }

    func prewarm(transform _: Transform) {}

    func prewarmAllTransforms() {}
}

final class TransformExecutorTests: XCTestCase {
    private func makeEnvironment(
        input: String = "hello world",
        clipboard: ClipboardCapture = ClipboardCapture(),
        modelClient: CountingModelClient = CountingModelClient()
    ) -> (AppEnvironment, ClipboardCapture, CountingModelClient) {
        let clipboardCapture = clipboard
        let environment = AppEnvironment(
            arguments: [],
            makeInputSource: { _ in
                InputSource(
                    readsStdin: false,
                    readStdin: { Data() },
                    readClipboard: { input }
                )
            },
            makeOutputSink: { _ in
                OutputSink(
                    writesClipboard: true,
                    writeStdout: { _ in },
                    writeClipboard: { text in
                        clipboardCapture.value = text
                        return true
                    }
                )
            },
            modelClient: modelClient,
            writeStdout: { _ in },
            writeStderr: { _ in }
        )
        return (environment, clipboardCapture, modelClient)
    }

    func testSuccessfulTransformWritesClipboardAndReturnsOutput() async throws {
        let (environment, clipboard, client) = makeEnvironment()

        let output = try await TransformExecutor.run(
            transform: .markdown,
            configuration: .clipboardOnly,
            environment: environment
        )

        XCTAssertEqual(output, "generated output")
        XCTAssertEqual(clipboard.value, "generated output")
        XCTAssertEqual(client.generateCallCount, 1)
    }

    func testEmptyInputThrowsNoInputAndSkipsModel() async {
        let countingClient = CountingModelClient()
        let (environment, _, _) = makeEnvironment(input: "   \n", modelClient: countingClient)

        do {
            _ = try await TransformExecutor.run(
                transform: .summary,
                configuration: .clipboardOnly,
                environment: environment
            )
            XCTFail("Expected noInput error")
        } catch let error as GenerationError {
            XCTAssertEqual(error, .noInput)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(countingClient.generateCallCount, 0)
    }

    func testUnsuitableInputThrowsAndSkipsModel() async {
        let countingClient = CountingModelClient()
        let (environment, _, _) = makeEnvironment(input: "23af655ba1dd", modelClient: countingClient)

        do {
            _ = try await TransformExecutor.run(
                transform: .summary,
                configuration: .clipboardOnly,
                environment: environment
            )
            XCTFail("Expected unsuitableInput error")
        } catch let error as GenerationError {
            XCTAssertEqual(error, .unsuitableInput)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(countingClient.generateCallCount, 0)
    }

    func testAvailabilityFailurePropagates() async {
        let countingClient = CountingModelClient(availabilityError: .appleIntelligenceNotEnabled)
        let (environment, _, _) = makeEnvironment(modelClient: countingClient)

        do {
            _ = try await TransformExecutor.run(
                transform: .summary,
                configuration: .clipboardOnly,
                environment: environment
            )
            XCTFail("Expected availability error")
        } catch let error as GenerationError {
            XCTAssertEqual(error, .appleIntelligenceNotEnabled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(countingClient.generateCallCount, 0)
    }

    func testClipboardWriteFailureThrows() async {
        let environment = AppEnvironment(
            arguments: [],
            makeInputSource: { _ in
                InputSource(
                    readsStdin: false,
                    readStdin: { Data() },
                    readClipboard: { "hello world" }
                )
            },
            makeOutputSink: { _ in
                OutputSink(
                    writesClipboard: true,
                    writeStdout: { _ in },
                    writeClipboard: { _ in false }
                )
            },
            modelClient: CountingModelClient(),
            writeStdout: { _ in },
            writeStderr: { _ in }
        )

        do {
            _ = try await TransformExecutor.run(
                transform: .summary,
                configuration: .clipboardOnly,
                environment: environment
            )
            XCTFail("Expected clipboardWriteFailed error")
        } catch let error as GenerationError {
            XCTAssertEqual(error, .clipboardWriteFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
