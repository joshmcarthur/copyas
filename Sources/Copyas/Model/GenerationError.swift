import Foundation

enum GenerationError: Error, Equatable {
    case missingTransform
    case noInput
    case unknownTransform(String)
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case modelUnavailable
    case generationFailed(String)

    var exitCode: Int32 {
        switch self {
        case .missingTransform, .unknownTransform:
            64
        case .noInput:
            6
        case .deviceNotEligible:
            2
        case .appleIntelligenceNotEnabled:
            3
        case .modelNotReady:
            4
        case .modelUnavailable:
            5
        case .generationFailed:
            1
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
        case .deviceNotEligible:
            "error: device does not support Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            "error: enable Apple Intelligence in System Settings"
        case .modelNotReady:
            "error: language model is not ready"
        case .modelUnavailable:
            "error: language model unavailable"
        case let .generationFailed(message):
            "error: generation failed: \(message)"
        }
    }
}
