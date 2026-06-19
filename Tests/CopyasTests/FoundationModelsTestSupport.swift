import FoundationModels
import XCTest

/// GitHub Actions and other headless macOS hosts may run macOS 26 without Apple Intelligence.
/// `SystemLanguageModel.availability` can be misleading; probe `tokenCount` before live FM tests.
enum FoundationModelsTestSupport {
    static func requireAvailableModel(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> SystemLanguageModel {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw XCTSkip(
                "SystemLanguageModel unavailable: \(model.availability)",
                file: file,
                line: line
            )
        }
        return model
    }

    @available(macOS 26.4, *)
    static func requireTokenCounting(
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> SystemLanguageModel {
        let model = try requireAvailableModel(file: file, line: line)
        do {
            _ = try await model.tokenCount(for: "probe")
        } catch {
            throw XCTSkip(
                "tokenCount unavailable (Apple Intelligence not enabled?): \(error)",
                file: file,
                line: line
            )
        }
        return model
    }
}
