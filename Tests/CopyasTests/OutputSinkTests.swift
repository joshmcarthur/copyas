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

    func testWritePartialAppendsWithoutNewline() {
        let stdout = OutputCapture()
        let sink = OutputSink(
            writesClipboard: false,
            writeStdout: { stdout.value += $0 },
            writeClipboard: { _ in true }
        )

        sink.writePartial("hel")
        sink.writePartial("lo")

        XCTAssertEqual(stdout.value, "hello")
    }

    func testFinalizeAddsTrailingNewlineWhenMissing() throws {
        let stdout = OutputCapture()
        let sink = OutputSink(
            writesClipboard: false,
            writeStdout: { stdout.value += $0 },
            writeClipboard: { _ in true }
        )

        sink.writePartial("hello")
        try sink.finalize("hello")

        XCTAssertEqual(stdout.value, "hello\n")
    }

    func testFinalizeDoesNotDuplicateNewline() throws {
        let stdout = OutputCapture()
        let sink = OutputSink(
            writesClipboard: false,
            writeStdout: { stdout.value += $0 },
            writeClipboard: { _ in true }
        )

        sink.writePartial("hello\n")
        try sink.finalize("hello\n")

        XCTAssertEqual(stdout.value, "hello\n")
    }

    func testWritePartialIsNoOpForClipboardMode() {
        let stdout = OutputCapture()
        let sink = OutputSink(
            writesClipboard: true,
            writeStdout: { stdout.value += $0 },
            writeClipboard: { _ in true }
        )

        sink.writePartial("hello")

        XCTAssertTrue(stdout.value.isEmpty)
    }
}
