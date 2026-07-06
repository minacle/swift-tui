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
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin",
            from: "1.5.0"
        ),
        .package(
            url: "https://github.com/minacle/swift-terminal",
            revision: "1f45bc5860f008543cd9a718fb1e66920ef9411d"
        ),
        .package(
            url: "https://github.com/minacle/swift-termios",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "SwiftTUI",
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
        .testTarget(
            name: "SwiftTUITests",
            dependencies: ["SwiftTUI"],
            swiftSettings: swiftSettings,
        ),
    ],
    swiftLanguageModes: [.v6],
)
