import Foundation

enum GenerationError: Error, Equatable, Sendable {
    case missingTransform

    var exitCode: Int32 {
        switch self {
        case .missingTransform:
            64
        }
    }

    var message: String {
        switch self {
        case .missingTransform:
            "error: missing required transform"
        }
    }
}
