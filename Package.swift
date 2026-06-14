// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "copyas",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "copyas", targets: ["CopyasCLI"]),
        .executable(name: "CopyasMenuBar", targets: ["CopyasMenuBar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "Copyas",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
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
            name: "CopyasTests",
            dependencies: ["Copyas"]
        ),
    ]
)
