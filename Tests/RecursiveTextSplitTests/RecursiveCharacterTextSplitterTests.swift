import Foundation
import RecursiveTextSplit
import XCTest

final class RecursiveCharacterTextSplitterTests: XCTestCase {
    func testMatchesLangChainGoldenFixtures() throws {
        let url = Bundle.module.url(
            forResource: "langchain_golden",
            withExtension: "json",
            subdirectory: "Fixtures"
        )
        let fixtureURL = url ?? Bundle.module.url(
            forResource: "langchain_golden",
            withExtension: "json"
        )
        XCTAssertNotNil(fixtureURL, "missing langchain_golden.json")

        let data = try Data(contentsOf: XCTUnwrap(fixtureURL))
        let payload = try JSONDecoder().decode(GoldenFixtures.self, from: data)

        for fixture in payload.fixtures {
            let config = SplitConfig(
                separators: fixture.separators,
                chunkSize: fixture.chunkSize,
                chunkOverlap: fixture.chunkOverlap
            )
            let splitter = RecursiveCharacterTextSplitter(config: config)
            let chunks = splitter.split(text: fixture.input)
            XCTAssertEqual(
                chunks,
                fixture.chunks,
                "fixture \(fixture.name) diverged from LangChain"
            )
        }
    }

    func testCJKSeparatorPresetIsDistinctFromDefault() {
        XCTAssertNotEqual(
            SplitConfig.langchainCJKSeparators,
            SplitConfig.langchainDefaultSeparators
        )
        XCTAssertTrue(SplitConfig.langchainCJKSeparators.contains("."))
    }
}

private struct GoldenFixtures: Decodable {
    let fixtures: [GoldenFixture]
}

private struct GoldenFixture: Decodable {
    let name: String
    let chunkSize: Int
    let chunkOverlap: Int
    let separators: [String]
    let input: String
    let chunks: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case chunkSize = "chunk_size"
        case chunkOverlap = "chunk_overlap"
        case separators
        case input
        case chunks
    }
}
