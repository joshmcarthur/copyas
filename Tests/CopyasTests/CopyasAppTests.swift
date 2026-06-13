@testable import Copyas
import XCTest

private final class OutputCapture: @unchecked Sendable {
    var value = ""
}

struct FakeModelClient: ModelClient {
    var output = "generated output"
    var availabilityError: GenerationError?

    func checkAvailability() throws {
        if let availabilityError {
            throw availabilityError
        }
    }

    func generate(
        transform _: Transform,
        input _: String,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        if let onPartial {
            var previousLength = 0
            for index in output.indices {
                let partial = String(output[...index])
                guard partial.count > previousLength else { continue }
                let delta = String(partial.dropFirst(previousLength))
                previousLength = partial.count
                onPartial(delta)
            }
        }
        return output
    }
}

final class CopyasAppTests: XCTestCase {
    private func makeEnvironment(
        arguments: [String],
        input: InputSource? = nil,
        output: OutputSink? = nil,
        modelClient: FakeModelClient = FakeModelClient(),
        stdout: OutputCapture,
        stderr: OutputCapture
    ) -> AppEnvironment {
        let writeStdout: @Sendable (String) -> Void = { stdout.value += $0 }

        return AppEnvironment(
            arguments: arguments,
            makeInputSource: { readsStdin in
                input ?? InputSource(
                    readsStdin: readsStdin,
                    readStdin: { Data("hello\n".utf8) },
                    readClipboard: { "hello" }
                )
            },
            makeOutputSink: { writesClipboard in
                output ?? OutputSink(
                    writesClipboard: writesClipboard,
                    writeStdout: writeStdout,
                    writeClipboard: { _ in true }
                )
            },
            modelClient: modelClient,
            writeStdout: writeStdout,
            writeStderr: { stderr.value += $0 }
        )
    }

    func testVersionWritesStdoutAndExitsZero() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["-v"],
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.value, "\(CopyasMetadata.version)\n")
        XCTAssertTrue(stderr.value.isEmpty)
    }

    func testMissingTransformWritesStderrAndExits64() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: [],
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 64)
        XCTAssertTrue(stderr.value.lowercased().contains("transform"))
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testUnknownTransformWritesStderrAndExits64() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["lolcat"],
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 64)
        XCTAssertEqual(stderr.value, "error: unknown transform \"lolcat\"\n")
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testEmptyInputWritesStderrAndExits6() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let emptyInput = InputSource(
            readsStdin: true,
            readStdin: { Data("\n".utf8) },
            readClipboard: { nil }
        )
        let environment = makeEnvironment(
            arguments: ["summary", "--stdin"],
            input: emptyInput,
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 6)
        XCTAssertEqual(stderr.value, "error: no input text\n")
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testUnsuitableInputWritesStderrAndExits7() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let hashInput = InputSource(
            readsStdin: true,
            readStdin: { Data("23af655ba1dd\n".utf8) },
            readClipboard: { nil }
        )
        let environment = makeEnvironment(
            arguments: ["summary", "--stdin"],
            input: hashInput,
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 7)
        XCTAssertEqual(
            stderr.value,
            "error: input does not contain enough meaningful text to transform\n"
        )
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testSuccessfulRunWritesGeneratedOutputAndNoStderr() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["summary", "--stdin"],
            modelClient: FakeModelClient(output: "generated output"),
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.value, "generated output\n")
        XCTAssertTrue(stderr.value.isEmpty)
    }

    func testWriteFlagWritesClipboardAndLeavesStdoutSilent() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let clipboard = OutputCapture()
        let output = OutputSink(
            writesClipboard: true,
            writeStdout: { stdout.value += $0 },
            writeClipboard: { text in
                clipboard.value = text
                return true
            }
        )
        let environment = makeEnvironment(
            arguments: ["summary", "-w"],
            output: output,
            modelClient: FakeModelClient(output: "generated output"),
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(clipboard.value, "generated output")
        XCTAssertTrue(stdout.value.isEmpty)
        XCTAssertTrue(stderr.value.isEmpty)
    }

    func testOutputAlreadyEndingWithNewlineIsNotDuplicated() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["summary", "--stdin"],
            modelClient: FakeModelClient(output: "generated output\n"),
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.value, "generated output\n")
        XCTAssertTrue(stderr.value.isEmpty)
    }

    func testStreamingRunWritesPartialsThenFinalizes() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["summary", "--stdin"],
            modelClient: FakeModelClient(output: "ab"),
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.value, "ab\n")
        XCTAssertTrue(stderr.value.isEmpty)
    }

    func testNoStreamFlagBuffersOutput() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["summary", "--stdin", "--no-stream"],
            modelClient: FakeModelClient(output: "generated output"),
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.value, "generated output\n")
        XCTAssertTrue(stderr.value.isEmpty)
    }

    func testDeviceNotEligibleExits2() async {
        await assertModelError(.deviceNotEligible, expectedExit: 2)
    }

    func testAppleIntelligenceNotEnabledExits3() async {
        await assertModelError(.appleIntelligenceNotEnabled, expectedExit: 3)
    }

    func testModelNotReadyExits4() async {
        await assertModelError(.modelNotReady, expectedExit: 4)
    }

    func testModelUnavailableExits5() async {
        await assertModelError(.modelUnavailable, expectedExit: 5)
    }

    func testGenerationFailedExits1() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let writeStdout: @Sendable (String) -> Void = { stdout.value += $0 }
        let failingEnvironment = AppEnvironment(
            arguments: ["summary", "--stdin"],
            makeInputSource: { readsStdin in
                InputSource(
                    readsStdin: readsStdin,
                    readStdin: { Data("hello\n".utf8) },
                    readClipboard: { "hello" }
                )
            },
            makeOutputSink: { writesClipboard in
                OutputSink(
                    writesClipboard: writesClipboard,
                    writeStdout: writeStdout,
                    writeClipboard: { _ in true }
                )
            },
            modelClient: FailingModelClient(),
            writeStdout: writeStdout,
            writeStderr: { stderr.value += $0 }
        )

        let exitCode = await CopyasApp.run(environment: failingEnvironment)

        XCTAssertEqual(exitCode, 1)
        XCTAssertEqual(stderr.value, "error: generation failed: boom\n")
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testHelpWritesStdoutAndExitsZero() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["-h"],
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertTrue(stdout.value.contains("USAGE:"))
        XCTAssertTrue(stderr.value.isEmpty)
    }

    private func assertModelError(_ error: GenerationError, expectedExit: Int32) async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["summary", "--stdin"],
            modelClient: FakeModelClient(availabilityError: error),
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, expectedExit)
        XCTAssertEqual(stderr.value, "\(error.message)\n")
        XCTAssertTrue(stdout.value.isEmpty)
    }
}

private struct FailingModelClient: ModelClient {
    func checkAvailability() throws {}

    func generate(
        transform _: Transform,
        input _: String,
        onPartial _: (@Sendable (String) -> Void)?
    ) async throws -> String {
        throw GenerationError.generationFailed("boom")
    }
}
