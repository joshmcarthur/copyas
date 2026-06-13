@testable import Copyas
import XCTest

private final class OutputCapture: @unchecked Sendable {
    var value = ""
}

final class OutputSinkTests: XCTestCase {
    func testStdoutWriteAddsTrailingNewline() throws {
        let stdout = OutputCapture()
        let sink = OutputSink(
            writesClipboard: false,
            writeStdout: { stdout.value += $0 },
            writeClipboard: { _ in true }
        )

        try sink.write("hello")

        XCTAssertEqual(stdout.value, "hello\n")
    }

    func testStdoutWriteDoesNotDuplicateNewline() throws {
        let stdout = OutputCapture()
        let sink = OutputSink(
            writesClipboard: false,
            writeStdout: { stdout.value += $0 },
            writeClipboard: { _ in true }
        )

        try sink.write("hello\n")

        XCTAssertEqual(stdout.value, "hello\n")
    }

    func testClipboardWriteLeavesStdoutSilent() throws {
        let stdout = OutputCapture()
        let clipboard = OutputCapture()
        let sink = OutputSink(
            writesClipboard: true,
            writeStdout: { stdout.value += $0 },
            writeClipboard: { text in
                clipboard.value = text
                return true
            }
        )

        try sink.write("generated output")

        XCTAssertEqual(clipboard.value, "generated output")
        XCTAssertTrue(stdout.value.isEmpty)
    }

    func testClipboardWriteFailureThrows() {
        let sink = OutputSink(
            writesClipboard: true,
            writeStdout: { _ in },
            writeClipboard: { _ in false }
        )

        XCTAssertThrowsError(try sink.write("hello")) { error in
            XCTAssertEqual(error as? GenerationError, .clipboardWriteFailed)
        }
    }
}
