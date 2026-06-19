@testable import Copyas
import XCTest

final class ChunkedGeneratorTests: XCTestCase {
    func testMapOnlyConcatenatesChunkOutputs() async throws {
        let budget = SynchronousTokenBudget(
            counter: FixedTextLengthCounter(contextSize: 10000, defaultLength: 500)
        )
        let callCounter = CallCounter()
        let input = String(repeating: "paragraph\n\n", count: 80)

        let output = try await ChunkedGenerator.generate(
            profile: Transform.pirate.chunkingProfile,
            mapInstructions: "map",
            input: input,
            budget: budget,
            onPartial: nil
        ) { _, chunk, _ in
            callCounter.increment()
            return "out-\(chunk.prefix(4))"
        }

        XCTAssertGreaterThan(callCounter.value, 1)
        XCTAssertTrue(output.contains("out-"))
        XCTAssertTrue(output.contains("\n\n"))
    }

    func testMapReduceMergesPartials() async throws {
        let budget = SynchronousTokenBudget(
            counter: FixedTextLengthCounter(contextSize: 10000, defaultLength: 400)
        )
        let input = String(repeating: "section\n\n", count: 60)
        let callLog = CallLog()

        let output = try await ChunkedGenerator.generate(
            profile: Transform.summary.chunkingProfile,
            mapInstructions: "map-summary",
            input: input,
            budget: budget,
            onPartial: nil
        ) { instructions, chunk, _ in
            callLog.append(instructions)
            if instructions == "map-summary" {
                return "- point from \(chunk.prefix(4))"
            }
            return "- merged \(chunk.prefix(8))"
        }

        XCTAssertTrue(callLog.values.contains("map-summary"))
        XCTAssertTrue(callLog.values
            .contains(where: { $0.contains("Merge the following bullet lists") }))
        XCTAssertTrue(output.contains("merged") || output.contains("point"))
    }

    func testMapReduceCollapseWhenReduceInputTooLarge() async throws {
        let budget = SynchronousTokenBudget(
            counter: FixedTextLengthCounter(contextSize: 2000, defaultLength: 150)
        )
        let input = String(repeating: "block\n\n", count: 20)

        let output = try await ChunkedGenerator.generate(
            profile: Transform.summary.chunkingProfile,
            mapInstructions: "map",
            input: input,
            budget: budget,
            onPartial: nil
        ) { instructions, _, _ in
            if instructions == "map" {
                return "- bullet\n"
            }
            return "- merged summary"
        }

        XCTAssertEqual(output, "- merged summary")
    }

    func testStuffModeSingleChunk() async throws {
        let budget = SynchronousTokenBudget(counter: FixedTextLengthCounter())
        let profile = TransformChunkingProfile(
            mode: .stuff,
            merge: .concatenate(separator: ""),
            outputTokenReserve: 0
        )

        let output = try await ChunkedGenerator.generate(
            profile: profile,
            mapInstructions: "do it",
            input: "hello",
            budget: budget,
            onPartial: nil
        ) { instructions, chunk, _ in
            XCTAssertEqual(instructions, "do it")
            XCTAssertEqual(chunk, "hello")
            return "done"
        }

        XCTAssertEqual(output, "done")
    }

    func testMapOnlyRejectsReduceMergeStrategy() async {
        let budget = SynchronousTokenBudget(counter: FixedTextLengthCounter())
        let profile = TransformChunkingProfile(
            mode: .mapOnly,
            merge: .reduce(instructions: "merge"),
            outputTokenReserve: 0
        )

        do {
            _ = try await ChunkedGenerator.generate(
                profile: profile,
                mapInstructions: "map",
                input: "hello",
                budget: budget,
                onPartial: nil
            ) { _, _, _ in "out" }
            XCTFail("expected invalid merge strategy error")
        } catch let error as GenerationError {
            XCTAssertEqual(
                error,
                .generationFailed("invalid merge strategy for map-only transform")
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMapReduceThrowsWhenCollapseDepthExceeded() async {
        let budget = SynchronousTokenBudget(
            counter: FixedTextLengthCounter(contextSize: 200, defaultLength: 80)
        )
        let profile = TransformChunkingProfile(
            mode: .mapReduce,
            merge: .reduce(instructions: "reduce these"),
            outputTokenReserve: 20,
            maxReduceDepth: 0
        )
        let input = String(repeating: "section\n\n", count: 10)

        do {
            _ = try await ChunkedGenerator.generate(
                profile: profile,
                mapInstructions: "map",
                input: input,
                budget: budget,
                onPartial: nil
            ) { instructions, _, _ in
                instructions == "map" ? "- bullet\n" : "merged"
            }
            XCTFail("expected context window exceeded")
        } catch let error as GenerationError {
            XCTAssertEqual(error, .contextWindowExceeded)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

private final class CallCounter: @unchecked Sendable {
    private var count = 0
    var value: Int {
        count
    }

    func increment() {
        count += 1
    }
}

private final class CallLog: @unchecked Sendable {
    private var items: [String] = []
    var values: [String] {
        items
    }

    func append(_ item: String) {
        items.append(item)
    }
}
