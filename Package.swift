// swift-tools-version: 6.3

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .strictMemorySafety(),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "swift-tui",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "SwiftTUI",
            targets: ["SwiftTUI"]
        ),
        .library(
            name: "SwiftTUIEssentials",
            targets: ["SwiftTUIEssentials"]
        ),
        .library(
            name: "SwiftTUIControls",
            targets: ["SwiftTUIControls"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin",
            from: "1.5.0"
        ),
        .package(
            url: "https://github.com/minacle/swift-terminal",
            exact: "0.0.2"
        ),
        .package(
            url: "https://github.com/minacle/swift-termios",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "SwiftTUIEssentials",
            dependencies: [
                .product(
                    name: "Terminal",
                    package: "swift-terminal"
                ),
                .product(
                    name: "Termios",
                    package: "swift-termios"
                ),
            ],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "SwiftTUIControls",
            dependencies: ["SwiftTUIEssentials"],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "SwiftTUI",
            dependencies: [
                "SwiftTUIControls",
                "SwiftTUIEssentials",
            ],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "SwiftTUIEssentialsTests",
            dependencies: [
                "SwiftTUIControls",
                "SwiftTUIEssentials",
            ],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "SwiftTUIControlsTests",
            dependencies: [
                "SwiftTUIControls",
                "SwiftTUIEssentials",
            ],
            swiftSettings: swiftSettings,
        ),
    ],
    swiftLanguageModes: [.v6],
)
