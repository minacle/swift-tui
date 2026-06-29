// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "swift-tui",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SwiftTUI",
            targets: ["SwiftTUI"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-system",
            from: "1.7.2"
        ),
        .package(
            url: "https://github.com/minacle/swift-terminal",
            branch: "main"
        ),
        .package(
            url: "https://github.com/minacle/swift-termios",
            branch: "main"
        ),
        .package(
            url: "https://github.com/OpenSwiftUIProject/OpenCombine.git",
            from: "0.15.0"
        ),
    ],
    targets: [
        .target(
            name: "SwiftTUI",
            dependencies: [
                .product(
                    name: "SystemPackage",
                    package: "swift-system"
                ),
                .product(
                    name: "Terminal",
                    package: "swift-terminal"
                ),
                .product(
                    name: "Termios",
                    package: "swift-termios"
                ),
                .product(
                    name: "OpenCombine",
                    package: "OpenCombine",
                    condition: .when(platforms: [.linux])
                ),
            ]
        ),
        .testTarget(
            name: "SwiftTUITests",
            dependencies: ["SwiftTUI"],
        ),
    ],
    swiftLanguageModes: [.v6],
)
