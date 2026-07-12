import Foundation
import FoundationModels
import TwoMillionKit

public enum ModelPreference: Sendable {
    case automatic
    case cloud
    case local
}

public enum ModelBackend: Sendable {
    case onDevice(SystemLanguageModel)
    case privateCloudCompute(FMToolLanguageModel)

    public var supportsStreaming: Bool {
        switch self {
        case .onDevice:
            true
        case .privateCloudCompute:
            false
        }
    }

    public func makeTokenCounter() -> any AsyncTokenCounter {
        switch self {
        case let .onDevice(model):
            FoundationModelsTokenCounter(model: model)
        case .privateCloudCompute:
            HeuristicTextLengthCounter(contextSize: HeuristicTextLengthCounter.defaultContextSize)
        }
    }

    public func makeSession(instructions: String) -> LanguageModelSession {
        switch self {
        case let .onDevice(model):
            LanguageModelSession(model: model, instructions: instructions)
        case let .privateCloudCompute(model):
            LanguageModelSession(model: model, instructions: instructions)
        }
    }
}
