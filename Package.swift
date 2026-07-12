// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "copyas",
    platforms: [.macOS(.v27)],
    products: [
        .executable(name: "copyas", targets: ["CopyasCLI"]),
        .executable(name: "CopyasMenuBar", targets: ["CopyasMenuBar"]),
        .library(name: "RecursiveTextSplit", targets: ["RecursiveTextSplit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/insidegui/TwoMillionKit", branch: "main"),
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
                .product(name: "TwoMillionKit", package: "TwoMillionKit"),
            ],
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
            dependencies: ["Copyas"]
        ),
    ]
)
