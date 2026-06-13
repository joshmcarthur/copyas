import ArgumentParser
@testable import Copyas
import XCTest

final class CLITests: XCTestCase {
    func testParsesTransformAndClipboardFlag() throws {
        let options = try CopyasOptions.parse(["-t", "summary", "-c"])

        XCTAssertEqual(options.transformName, "summary")
        XCTAssertTrue(options.readsClipboard)
    }
}
