@testable import Copyas
import XCTest

final class TransformTests: XCTestCase {
    func testResolvesTransformsCaseInsensitively() {
        XCTAssertEqual(Transform.named("summary"), .summary)
        XCTAssertEqual(Transform.named("SUMMARY"), .summary)
        XCTAssertEqual(Transform.named("Markdown"), .markdown)
        XCTAssertEqual(Transform.named("pirate"), .pirate)
    }

    func testExposesSpecAlignedInstructions() {
        XCTAssertTrue(Transform.summary.instructions.contains("Use `-` for bullets"))
        XCTAssertTrue(Transform.summary.instructions.contains("__COPYAS_REFUSE__"))
        XCTAssertTrue(Transform.markdown.instructions.contains("Do not wrap the entire response"))
        XCTAssertTrue(Transform.pirate.instructions.contains("Keep the original meaning"))
    }

    func testUnknownTransformReturnsNil() {
        XCTAssertNil(Transform.named("lolcat"))
    }
}
