import ArgumentParser
@testable import Copyas
import XCTest

final class CLITests: XCTestCase {
    func testParsesPositionalTransform() throws {
        let options = try CopyasOptions.parse(["summary"])

        XCTAssertEqual(options.transform, "summary")
        XCTAssertFalse(options.readsStdin)
        XCTAssertFalse(options.writesClipboard)
        XCTAssertFalse(options.noStream)
    }

    func testParsesStdinFlag() throws {
        let options = try CopyasOptions.parse(["summary", "--stdin"])

        XCTAssertEqual(options.transform, "summary")
        XCTAssertTrue(options.readsStdin)
        XCTAssertFalse(options.writesClipboard)
    }

    func testParsesWriteFlag() throws {
        let options = try CopyasOptions.parse(["markdown", "-w"])

        XCTAssertEqual(options.transform, "markdown")
        XCTAssertFalse(options.readsStdin)
        XCTAssertTrue(options.writesClipboard)
    }

    func testParsesNoStreamFlag() throws {
        let options = try CopyasOptions.parse(["summary", "--stdin", "--no-stream"])

        XCTAssertEqual(options.transform, "summary")
        XCTAssertTrue(options.readsStdin)
        XCTAssertFalse(options.writesClipboard)
        XCTAssertTrue(options.noStream)
    }
}
