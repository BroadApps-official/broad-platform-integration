// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BroadPlatformIntegration",
    platforms: [
        .iOS(.v17),
    ],
    dependencies: [
        .package(
            url: "https://github.com/BroadApps-official/broad-extensions-ios.git",
            exact: "1.0.1"
        ),
        .package(
            url: "https://github.com/BroadApps-official/broad-core-ios.git",
            exact: "3.0.0"
        ),
        .package(
            url: "https://github.com/BroadApps-official/broad-monetization-ios.git",
            exact: "5.0.0"
        ),
        .package(
            url: "https://github.com/BroadApps-official/broad-ui-flows-ios.git",
            exact: "5.0.0"
        ),
        // Integration showcase only; host apps choose optional products.
        .package(url: "https://github.com/BroadApps-official/broad-ru-billing-ios.git", exact: "1.0.0"),
        .package(
            url: "https://github.com/Swinject/Swinject.git",
            exact: "2.10.0"
        ),
    ],
    targets: [],
    swiftLanguageModes: [.v5]
)
