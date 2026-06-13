@testable import Copyas
import XCTest

final class TransformOutputTests: XCTestCase {
    func testParsesNormalResponse() throws {
        let output = try TransformOutput.parse("- One point\n- Two points\n")
        XCTAssertEqual(output, "- One point\n- Two points\n")
    }

    func testRejectsRefusalMarker() {
        XCTAssertThrowsError(try TransformOutput.parse("__COPYAS_REFUSE__")) { error in
            XCTAssertEqual(error as? GenerationError, .unsuitableInput)
        }
    }

    func testRejectsTrimmedRefusalMarker() {
        XCTAssertThrowsError(try TransformOutput.parse("  __COPYAS_REFUSE__\n")) { error in
            XCTAssertEqual(error as? GenerationError, .unsuitableInput)
        }
    }
}
