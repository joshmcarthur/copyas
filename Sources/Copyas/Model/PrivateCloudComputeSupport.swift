import Foundation

enum PrivateCloudComputeSupport {
    static var isRuntimeSupported: Bool {
        #if COPYAS_ENABLE_PCC
        if #available(macOS 27, *) {
            return true
        }
        #endif
        return false
    }

    static func isFMExecutableAvailable(at url: URL) -> Bool {
        guard isRuntimeSupported else { return false }
        return FileManager.default.isExecutableFile(atPath: url.path)
    }
}
