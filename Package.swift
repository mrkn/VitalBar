// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VitalBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "VitalBarCore",
            targets: ["VitalBarCore"]
        ),
        .executable(
            name: "VitalBarApp",
            targets: ["VitalBarApp"]
        ),
    ],
    targets: [
        .target(
            name: "VitalBarCore",
            path: "Sources/VitalBarCore"
        ),
        .executableTarget(
            name: "VitalBarApp",
            dependencies: ["VitalBarCore"],
            path: "Sources/VitalBarApp"
        ),
        .testTarget(
            name: "VitalBarCoreTests",
            dependencies: ["VitalBarCore"],
            path: "Tests/VitalBarCoreTests"
        ),
        .testTarget(
            name: "VitalBarAppTests",
            dependencies: ["VitalBarApp", "VitalBarCore"],
            path: "Tests/VitalBarAppTests"
        ),
    ]
)
