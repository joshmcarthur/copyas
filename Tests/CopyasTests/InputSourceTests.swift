import AppKit
@testable import Copyas
import Foundation
import XCTest

final class InputSourceTests: XCTestCase {
    func testStdinInputPreservesLeadingWhitespaceAndTrimsTrailingWhitespace() throws {
        let source = InputSource(
            readsStdin: true,
            readStdin: { Data("  hello\n\n".utf8) },
            readClipboard: { nil }
        )

        XCTAssertEqual(try source.readText(), "  hello")
    }

    func testClipboardUsedByDefault() throws {
        let source = InputSource(
            readsStdin: false,
            readStdin: { Data("stdin".utf8) },
            readClipboard: { "clipboard\n" }
        )

        XCTAssertEqual(try source.readText(), "clipboard")
    }

    func testEmptyAfterTrailingTrimThrowsNoInput() {
        let source = InputSource(
            readsStdin: true,
            readStdin: { Data("\n\t ".utf8) },
            readClipboard: { nil }
        )

        XCTAssertThrowsError(try source.readText()) { error in
            XCTAssertEqual(error as? GenerationError, .noInput)
        }
    }

    func testLiveReadsClipboard() throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        XCTAssertTrue(pasteboard.setString("live clipboard\n", forType: .string))

        let source = InputSource.live(readsStdin: false)

        XCTAssertEqual(try source.readText(), "live clipboard")
    }

    func testLiveEmptyClipboardThrowsNoInput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let source = InputSource.live(readsStdin: false)

        XCTAssertThrowsError(try source.readText()) { error in
            XCTAssertEqual(error as? GenerationError, .noInput)
        }
    }
}
