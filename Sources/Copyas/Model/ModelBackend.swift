import Foundation
import FoundationModels

public enum ModelPreference: Sendable {
    case automatic
    case cloud
    case local
}

public enum ModelBackend: Sendable {
    case onDevice(SystemLanguageModel)
    #if COPYAS_ENABLE_PCC
    case privateCloudCompute(FMToolLanguageModel)
    #endif

    public var supportsStreaming: Bool {
        switch self {
        case .onDevice:
            true
        #if COPYAS_ENABLE_PCC
        case .privateCloudCompute:
            false
        #endif
        }
    }

    public func makeTokenCounter() -> any AsyncTokenCounter {
        switch self {
        case let .onDevice(model):
            FoundationModelsTokenCounter(model: model)
        #if COPYAS_ENABLE_PCC
        case .privateCloudCompute:
            HeuristicTextLengthCounter(contextSize: HeuristicTextLengthCounter.defaultContextSize)
        #endif
        }
    }

    public func makeSession(instructions: String) -> LanguageModelSession {
        switch self {
        case let .onDevice(model):
            LanguageModelSession(model: model, instructions: instructions)
        #if COPYAS_ENABLE_PCC
        case let .privateCloudCompute(model):
            LanguageModelSession(model: model, instructions: instructions)
        #endif
        }
    }
}
