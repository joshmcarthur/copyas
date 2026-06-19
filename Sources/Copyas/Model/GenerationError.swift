import Foundation

public enum GenerationError: Error, Equatable {
    case missingTransform
    case noInput
    case unsuitableInput
    case unknownTransform(String)
    case clipboardWriteFailed
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case modelUnavailable
    case modelAssetsUnavailable
    case contentBlocked
    case contextWindowExceeded
    case generationFailed(String)

    var exitCode: Int32 {
        switch self {
        case .missingTransform, .unknownTransform:
            64
        case .noInput:
            6
        case .unsuitableInput:
            7
        case .deviceNotEligible:
            2
        case .appleIntelligenceNotEnabled:
            3
        case .modelNotReady, .modelAssetsUnavailable:
            4
        case .modelUnavailable:
            5
        case .contentBlocked, .generationFailed, .clipboardWriteFailed, .contextWindowExceeded:
            1
        }
    }

    private var displayMessage: String {
        switch self {
        case .missingTransform:
            "missing required transform"
        case .noInput:
            "no input text"
        case .unsuitableInput:
            "input does not contain enough meaningful text to transform"
        case let .unknownTransform(name):
            "unknown transform \"\(name)\""
        case .clipboardWriteFailed:
            "failed to write to clipboard"
        case .deviceNotEligible:
            "device does not support Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            "enable Apple Intelligence in System Settings"
        case .modelNotReady:
            "language model is not ready"
        case .modelUnavailable:
            "language model unavailable"
        case .modelAssetsUnavailable:
            "Apple Intelligence model assets are unavailable; toggle Apple Intelligence off and on in System Settings, then restart your Mac"
        case .contentBlocked:
            "generation blocked by Apple Intelligence safety guardrails"
        case .contextWindowExceeded:
            "text is too long even after splitting; try with shorter text"
        case let .generationFailed(message):
            "generation failed: \(message)"
        }
    }

    public var message: String {
        "error: \(displayMessage)"
    }

    public var userFacingMessage: String {
        displayMessage
    }
}
