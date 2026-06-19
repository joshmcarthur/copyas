@testable import Copyas
import RecursiveTextSplit
import XCTest

final class TransformChunkingProfileTests: XCTestCase {
    func testSummaryUsesMapReduceWithReduceMerge() {
        let profile = Transform.summary.chunkingProfile
        XCTAssertEqual(profile.mode, .mapReduce)
        guard case .reduce = profile.merge else {
            XCTFail("expected reduce merge for summary")
            return
        }
        XCTAssertEqual(profile.maxReduceDepth, 3)
    }

    func testPirateUsesMapOnlyConcatenation() {
        let profile = Transform.pirate.chunkingProfile
        XCTAssertEqual(profile.mode, .mapOnly)
        guard case let .concatenate(separator) = profile.merge else {
            XCTFail("expected concatenate merge for pirate")
            return
        }
        XCTAssertEqual(separator, "\n\n")
    }

    func testMarkdownUsesDefaultSeparators() {
        let profile = Transform.markdown.chunkingProfile
        XCTAssertEqual(profile.split.separators, SplitConfig.langchainDefaultSeparators)
    }
}
