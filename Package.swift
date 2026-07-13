// swift-tools-version: 6.2
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

let copyasDependencies: [Target.Dependency] = {
    var dependencies: [Target.Dependency] = [
        "RecursiveTextSplit",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
    ]
    if enablePCC {
        dependencies.append("TwoMillionKit")
    }
    return dependencies
}()

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
    targets: {
        var targets: [Target] = [
            .target(
                name: "RecursiveTextSplit",
                path: "Sources/RecursiveTextSplit"
            ),
            .target(
                name: "Copyas",
                dependencies: copyasDependencies,
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

        if enablePCC {
            targets.insert(
                .target(
                    name: "TwoMillionKit",
                    path: "Vendor/TwoMillionKit/Sources/TwoMillionKit",
                    linkerSettings: [
                        .linkedFramework("FoundationModels"),
                    ]
                ),
                at: 1
            )
        }

        return targets
    }()
)
