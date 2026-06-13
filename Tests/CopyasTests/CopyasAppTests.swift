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

    func generate(transform _: Transform, input _: String) async throws -> String {
        output
    }
}

final class CopyasAppTests: XCTestCase {
    private func makeEnvironment(
        arguments: [String],
        input: InputSource? = nil,
        modelClient: FakeModelClient = FakeModelClient(),
        stdout: OutputCapture,
        stderr: OutputCapture
    ) -> AppEnvironment {
        AppEnvironment(
            arguments: arguments,
            inputSource: { _ in
                input ?? InputSource(
                    readsClipboard: false,
                    readStdin: { Data("hello\n".utf8) },
                    readClipboard: { nil }
                )
            },
            modelClient: modelClient,
            writeStdout: { stdout.value += $0 },
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
        XCTAssertEqual(stdout.value, "copyas 0.1.0\n")
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
        XCTAssertEqual(stderr.value, "error: missing required transform\n")
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testUnknownTransformWritesStderrAndExits64() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["-t", "lolcat"],
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
            readsClipboard: false,
            readStdin: { Data("\n".utf8) },
            readClipboard: { nil }
        )
        let environment = makeEnvironment(
            arguments: ["-t", "summary"],
            input: emptyInput,
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 6)
        XCTAssertEqual(stderr.value, "error: no input text\n")
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testSuccessfulRunWritesGeneratedOutputAndNoStderr() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["-t", "summary"],
            modelClient: FakeModelClient(output: "generated output"),
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.value, "generated output\n")
        XCTAssertTrue(stderr.value.isEmpty)
    }

    func testOutputAlreadyEndingWithNewlineIsNotDuplicated() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["-t", "summary"],
            modelClient: FakeModelClient(output: "generated output\n"),
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
        let failingEnvironment = AppEnvironment(
            arguments: ["-t", "summary"],
            inputSource: { _ in
                InputSource(
                    readsClipboard: false,
                    readStdin: { Data("hello\n".utf8) },
                    readClipboard: { nil }
                )
            },
            modelClient: FailingModelClient(),
            writeStdout: { stdout.value += $0 },
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
            arguments: ["-t", "summary"],
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

    func generate(transform _: Transform, input _: String) async throws -> String {
        throw GenerationError.generationFailed("boom")
    }
}
