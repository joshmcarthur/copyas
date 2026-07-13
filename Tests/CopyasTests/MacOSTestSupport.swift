import XCTest

enum MacOSTestSupport {
    static var isMacOS27OrLater: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }

    static func skipUnlessMacOS27(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard isMacOS27OrLater else {
            throw XCTSkip(
                "Requires macOS 27 for Private Cloud Compute",
                file: file,
                line: line
            )
        }
    }
}
