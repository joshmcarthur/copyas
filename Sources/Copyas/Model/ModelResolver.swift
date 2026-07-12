import Foundation
import FoundationModels
import TwoMillionKit

public enum ModelResolver {
    public static let defaultFMExecutablePath = "/usr/bin/fm"

    public static func resolve(
        preference: ModelPreference,
        fmExecutableURL: URL = URL(fileURLWithPath: defaultFMExecutablePath)
    ) throws -> ModelBackend {
        switch preference {
        case .cloud:
            return try makeCloudBackend(fmExecutableURL: fmExecutableURL)
        case .local:
            return makeOnDeviceBackend()
        case .automatic:
            if FileManager.default.isExecutableFile(atPath: fmExecutableURL.path) {
                return try makeCloudBackend(fmExecutableURL: fmExecutableURL)
            }
            return makeOnDeviceBackend()
        }
    }

    private static func makeOnDeviceBackend() -> ModelBackend {
        .onDevice(.default)
    }

    private static func makeCloudBackend(fmExecutableURL: URL) throws -> ModelBackend {
        guard FileManager.default.isExecutableFile(atPath: fmExecutableURL.path) else {
            throw GenerationError.cloudModelUnavailable
        }
        return .privateCloudCompute(
            FMToolLanguageModel(
                model: .privateCloudCompute,
                executableURL: fmExecutableURL
            )
        )
    }
}
