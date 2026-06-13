import ArgumentParser
@testable import Copyas
import XCTest

final class CLITests: XCTestCase {
    func testParsesTransformAndClipboardFlag() throws {
        let options = try CopyasOptions.parse(["-t", "summary", "-c"])

        XCTAssertEqual(options.transformName, "summary")
        XCTAssertTrue(options.readsClipboard)
        XCTAssertFalse(options.showsVersion)
    }

    func testVersionDoesNotRequireTransform() throws {
        let options = try CopyasOptions.parse(["-v"])

        XCTAssertNil(options.transformName)
        XCTAssertTrue(options.showsVersion)
    }

    func testMissingTransformIsUsageErrorWhenNotShowingVersion() throws {
        let options = try CopyasOptions.parse([])

        XCTAssertThrowsError(try options.requiredTransformName()) { error in
            XCTAssertEqual(error as? GenerationError, .missingTransform)
        }
    }
}
