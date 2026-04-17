// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OpenCodexComputerUse",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "OpenCodexComputerUseKit",
            targets: ["OpenCodexComputerUseKit"]
        ),
        .executable(
            name: "OpenCodexComputerUse",
            targets: ["OpenCodexComputerUse"]
        ),
        .executable(
            name: "OpenCodexComputerUseFixture",
            targets: ["OpenCodexComputerUseFixture"]
        ),
        .executable(
            name: "OpenCodexComputerUseSmokeSuite",
            targets: ["OpenCodexComputerUseSmokeSuite"]
        ),
    ],
    targets: [
        .target(
            name: "OpenCodexComputerUseKit",
            path: "packages/OpenCodexComputerUseKit/Sources/OpenCodexComputerUseKit"
        ),
        .executableTarget(
            name: "OpenCodexComputerUse",
            dependencies: ["OpenCodexComputerUseKit"],
            path: "apps/OpenCodexComputerUse/Sources/OpenCodexComputerUse"
        ),
        .executableTarget(
            name: "OpenCodexComputerUseFixture",
            dependencies: ["OpenCodexComputerUseKit"],
            path: "apps/OpenCodexComputerUseFixture/Sources/OpenCodexComputerUseFixture"
        ),
        .executableTarget(
            name: "OpenCodexComputerUseSmokeSuite",
            dependencies: ["OpenCodexComputerUseKit"],
            path: "apps/OpenCodexComputerUseSmokeSuite/Sources/OpenCodexComputerUseSmokeSuite"
        ),
        .testTarget(
            name: "OpenCodexComputerUseKitTests",
            dependencies: ["OpenCodexComputerUseKit"],
            path: "packages/OpenCodexComputerUseKit/Tests/OpenCodexComputerUseKitTests"
        ),
    ]
)
