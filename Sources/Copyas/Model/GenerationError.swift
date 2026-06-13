import Foundation

enum GenerationError: Error, Equatable, Sendable {
    case missingTransform
    case noInput
    case unknownTransform(String)

    var exitCode: Int32 {
        switch self {
        case .missingTransform, .unknownTransform:
            64
        case .noInput:
            6
        }
    }

    var message: String {
        switch self {
        case .missingTransform:
            "error: missing required transform"
        case .noInput:
            "error: no input text"
        case let .unknownTransform(name):
            "error: unknown transform \"\(name)\""
        }
    }
}
