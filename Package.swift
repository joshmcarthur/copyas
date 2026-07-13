// swift-tools-version: 6.2
import Foundation
import PackageDescription

let enablePCC: Bool = {
    if ProcessInfo.processInfo.environment["COPYAS_ENABLE_PCC"] == "0" {
        return false
    }
    if ProcessInfo.processInfo.environment["COPYAS_ENABLE_PCC"] == "1" {
        return true
    }
    return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
}()

let copyasSwiftSettings: [SwiftSetting] = enablePCC
    ? [.define("COPYAS_ENABLE_PCC")]
    : []

let package = Package(
    name: "copyas",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "copyas", targets: ["CopyasCLI"]),
        .executable(name: "CopyasMenuBar", targets: ["CopyasMenuBar"]),
        .library(name: "RecursiveTextSplit", targets: ["RecursiveTextSplit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "RecursiveTextSplit",
            path: "Sources/RecursiveTextSplit"
        ),
        .target(
            name: "Copyas",
            dependencies: [
                "RecursiveTextSplit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: copyasSwiftSettings,
            linkerSettings: [
                .linkedFramework("FoundationModels"),
            ]
        ),
        .executableTarget(
            name: "CopyasCLI",
            dependencies: ["Copyas"],
            path: "Sources/CopyasCLI"
        ),
        .executableTarget(
            name: "CopyasMenuBar",
            dependencies: ["Copyas"],
            path: "Sources/CopyasMenuBar",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .testTarget(
            name: "RecursiveTextSplitTests",
            dependencies: ["RecursiveTextSplit"],
            path: "Tests/RecursiveTextSplitTests",
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "CopyasTests",
            dependencies: ["Copyas"],
            swiftSettings: copyasSwiftSettings
        ),
    ]
)
