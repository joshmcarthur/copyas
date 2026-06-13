import Foundation

enum TransformOutput {
    static let refusalMarker = "__COPYAS_REFUSE__"

    static func parse(_ response: String) throws -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != refusalMarker else {
            throw GenerationError.unsuitableInput
        }
        return response
    }
}
