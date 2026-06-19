import RecursiveTextSplit
import XCTest

final class SplitConfigTests: XCTestCase {
    func testLangchainDefaultSeparatorsMatchDocumentation() {
        XCTAssertEqual(
            SplitConfig.langchainDefaultSeparators,
            ["\n\n", "\n", " ", ""]
        )
    }

    func testWithChunkSizeUpdatesOnlyChunkSize() {
        let base = SplitConfig.langchainDefault(chunkSize: 100, chunkOverlap: 10)
        let updated = base.with(chunkSize: 200)
        XCTAssertEqual(updated.chunkSize, 200)
        XCTAssertEqual(updated.chunkOverlap, 10)
        XCTAssertEqual(updated.separators, base.separators)
    }
}
