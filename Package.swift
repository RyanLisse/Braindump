// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Braindump",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "braindump", targets: ["BraindumpExec"]),
        .library(name: "BraindumpCLI", targets: ["BraindumpCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.3"),
        .package(url: "https://github.com/steipete/demark", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "BraindumpCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Demark", package: "demark"),
            ],
            path: "Sources/BraindumpCLI",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "BraindumpExec",
            dependencies: ["BraindumpCLI"],
            path: "Sources/BraindumpExec"
        ),
        .testTarget(
            name: "BraindumpTests",
            dependencies: ["BraindumpCLI"],
            path: "Tests/BraindumpTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
