@testable import Copyas
import XCTest

final class TransformRegistryTests: XCTestCase {
    func testResolvesTransformsCaseInsensitively() {
        XCTAssertEqual(TransformRegistry.resolve("summary"), .summary)
        XCTAssertEqual(TransformRegistry.resolve("SUMMARY"), .summary)
        XCTAssertEqual(TransformRegistry.resolve("Markdown"), .markdown)
        XCTAssertEqual(TransformRegistry.resolve("pirate"), .pirate)
    }

    func testExposesSpecAlignedInstructions() {
        XCTAssertTrue(Transform.summary.instructions.contains("Use `-` for bullets"))
        XCTAssertTrue(Transform.markdown.instructions.contains("Do not wrap the entire response"))
        XCTAssertTrue(Transform.pirate.instructions.contains("Keep the original meaning"))
    }

    func testUnknownTransformReturnsNil() {
        XCTAssertNil(TransformRegistry.resolve("lolcat"))
    }
}
