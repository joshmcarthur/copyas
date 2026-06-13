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
}
