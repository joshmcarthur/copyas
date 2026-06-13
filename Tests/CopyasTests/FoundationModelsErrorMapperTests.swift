import Foundation
@testable import Copyas
import XCTest

final class FoundationModelsErrorMapperTests: XCTestCase {
    func testMapsModelManagerError1013ToModelAssetsUnavailable() {
        let error = nestedError(
            outerDomain: "FoundationModels.LanguageModelSession.GenerationError",
            outerCode: -1,
            innerDomain: "com.apple.SensitiveContentAnalysisML",
            innerCode: 15,
            deepestDomain: "ModelManagerServices.ModelManagerError",
            deepestCode: 1013
        )

        XCTAssertEqual(FoundationModelsErrorMapper.map(error), .modelAssetsUnavailable)
    }

    func testMapsModelManagerError1026ToModelAssetsUnavailable() {
        let error = NSError(
            domain: "ModelManagerServices.ModelManagerError",
            code: 1026
        )

        XCTAssertEqual(FoundationModelsErrorMapper.map(error), .modelAssetsUnavailable)
    }

    func testMapsUnifiedAssetFrameworkErrorToModelAssetsUnavailable() {
        let error = NSError(
            domain: "com.apple.UnifiedAssetFramework",
            code: 5000,
            userInfo: [
                NSLocalizedFailureReasonErrorKey:
                    "There are no underlying assets for consistency token for asset set com.apple.modelcatalog",
            ]
        )

        XCTAssertEqual(FoundationModelsErrorMapper.map(error), .modelAssetsUnavailable)
    }

    func testMapsGuardrailViolationToContentBlocked() {
        let error = TestError(
            description: """
            guardrailViolation(FoundationModels.LanguageModelSession.GenerationError.Context(\
            debugDescription: "May contain sensitive or unsafe content", underlyingErrors: []))
            """
        )

        XCTAssertEqual(FoundationModelsErrorMapper.map(error), .contentBlocked)
    }

    func testMapsUnknownErrorToGenerationFailed() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])

        XCTAssertEqual(
            FoundationModelsErrorMapper.map(error),
            .generationFailed(String(describing: error))
        )
    }

    func testPassesThroughGenerationError() {
        XCTAssertEqual(
            FoundationModelsErrorMapper.map(GenerationError.noInput),
            .noInput
        )
    }

    func testModelAssetsUnavailableExitCodeAndMessage() {
        XCTAssertEqual(GenerationError.modelAssetsUnavailable.exitCode, 4)
        XCTAssertTrue(GenerationError.modelAssetsUnavailable.message.contains("model assets are unavailable"))
    }

    private func nestedError(
        outerDomain: String,
        outerCode: Int,
        innerDomain: String,
        innerCode: Int,
        deepestDomain: String,
        deepestCode: Int
    ) -> NSError {
        let deepest = NSError(domain: deepestDomain, code: deepestCode)
        let inner = NSError(
            domain: innerDomain,
            code: innerCode,
            userInfo: [NSMultipleUnderlyingErrorsKey: [deepest]]
        )
        return NSError(
            domain: outerDomain,
            code: outerCode,
            userInfo: [NSMultipleUnderlyingErrorsKey: [inner]]
        )
    }
}

private struct TestError: Error, CustomStringConvertible {
    let description: String
}
