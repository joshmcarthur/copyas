import XCTest
@testable import Copyas

final class CopyasAppTests: XCTestCase {
    private final class OutputCapture: @unchecked Sendable {
        var value = ""
    }

    func testEmptyAppReturnsSuccess() async {
        let environment = AppEnvironment(
            arguments: [],
            writeStdout: { _ in },
            writeStderr: { _ in }
        )

        let exitCode = await CopyasApp.run(environment: environment)
        XCTAssertEqual(exitCode, 64)
    }

    func testVersionWritesStdoutAndExitsZero() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = AppEnvironment(
            arguments: ["-v"],
            writeStdout: { stdout.value += $0 },
            writeStderr: { stderr.value += $0 }
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.value, "copyas 0.1.0\n")
        XCTAssertTrue(stderr.value.isEmpty)
    }

    func testMissingTransformWritesStderrAndExits64() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = AppEnvironment(
            arguments: [],
            writeStdout: { stdout.value += $0 },
            writeStderr: { stderr.value += $0 }
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 64)
        XCTAssertEqual(stderr.value, "error: missing required transform\n")
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testHelpWritesStdoutAndExitsZero() async {
        let stdout = OutputCapture()
        let stderr = OutputCapture()
        let environment = AppEnvironment(
            arguments: ["-h"],
            writeStdout: { stdout.value += $0 },
            writeStderr: { stderr.value += $0 }
        )

        let exitCode = await CopyasApp.run(environment: environment)

        XCTAssertEqual(exitCode, 0)
        XCTAssertTrue(stdout.value.contains("USAGE:"))
        XCTAssertTrue(stderr.value.isEmpty)
    }
}
