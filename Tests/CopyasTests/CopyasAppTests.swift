import XCTest
@testable import Copyas

final class CopyasAppTests: XCTestCase {
    private final class OutputCapture: @unchecked Sendable {
        var value = ""
    }

    func testEmptyAppReturnsSuccess() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = makeEnvironment(
            arguments: ["-t", "summary"],
            stdout: stdout,
            stderr: stderr
        )

        let exitCode = await CopyasApp.run(environment: environment)
        XCTAssertEqual(exitCode, 0)
    }

    private func makeEnvironment(
        arguments: [String],
        input: InputSource? = nil,
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
            writeStdout: { stdout.value += $0 },
            writeStderr: { stderr.value += $0 }
        )
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
}
