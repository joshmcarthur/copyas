@testable import Copyas
import XCTest

final class GenerationErrorTests: XCTestCase {
    func testMessagesPrefixDisplayTextWithErrorLabel() {
        XCTAssertEqual(
            GenerationError.missingTransform.message,
            "error: missing required transform"
        )
        XCTAssertEqual(
            GenerationError.missingTransform.userFacingMessage,
            "missing required transform"
        )
        XCTAssertEqual(
            GenerationError.unknownTransform("lolcat").message,
            "error: unknown transform \"lolcat\""
        )
        XCTAssertEqual(
            GenerationError.generationFailed("boom").message,
            "error: generation failed: boom"
        )
        XCTAssertEqual(
            GenerationError.contextWindowExceeded.message,
            "error: clipboard text is too long to transform in one pass; try with shorter text"
        )
    }

    func testExitCodes() {
        XCTAssertEqual(GenerationError.missingTransform.exitCode, 64)
        XCTAssertEqual(GenerationError.noInput.exitCode, 6)
        XCTAssertEqual(GenerationError.unsuitableInput.exitCode, 7)
        XCTAssertEqual(GenerationError.deviceNotEligible.exitCode, 2)
        XCTAssertEqual(GenerationError.appleIntelligenceNotEnabled.exitCode, 3)
        XCTAssertEqual(GenerationError.modelNotReady.exitCode, 4)
        XCTAssertEqual(GenerationError.modelUnavailable.exitCode, 5)
        XCTAssertEqual(GenerationError.clipboardWriteFailed.exitCode, 1)
        XCTAssertEqual(GenerationError.contentBlocked.exitCode, 1)
        XCTAssertEqual(GenerationError.contextWindowExceeded.exitCode, 1)
    }
}
