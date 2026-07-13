import Foundation

enum PrivateCloudComputeSupport {
    static func isFMExecutableAvailable(at url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }
}
