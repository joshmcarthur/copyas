@testable import Copyas
import XCTest

final class InputSuitabilityTests: XCTestCase {
    func testRejectsBareHashLikeInput() throws {
        XCTAssertThrowsError(try InputSuitability.validate("23af655ba1dd")) { error in
            XCTAssertEqual(error as? GenerationError, .unsuitableInput)
        }
    }

    func testRejectsNumbersOnlyInput() throws {
        XCTAssertThrowsError(try InputSuitability.validate("1234567890")) { error in
            XCTAssertEqual(error as? GenerationError, .unsuitableInput)
        }
    }

    func testAcceptsMeaningfulText() throws {
        XCTAssertNoThrow(try InputSuitability.validate("Meeting notes from Tuesday about the project timeline."))
        XCTAssertNoThrow(try InputSuitability.validate("Hello world"))
    }

    func testLongestAlphabeticTokenIgnoresDigitsAndPunctuation() {
        XCTAssertEqual(InputSuitability.longestAlphabeticToken(in: "23af655ba1dd"), 2)
        XCTAssertEqual(InputSuitability.longestAlphabeticToken(in: "Hello world"), 5)
    }
}
