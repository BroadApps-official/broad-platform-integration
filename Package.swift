// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BroadAppsIOSPlatform",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "BroadCore", targets: ["BroadCore"]),
        .library(name: "BroadMonetization", targets: ["BroadMonetization"]),
        .library(name: "BroadUIFlows", targets: ["BroadUIFlows"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Swinject/Swinject.git",
            exact: "2.10.0"
        ),
        .package(
            url: "https://github.com/adaptyteam/AdaptySDK-iOS.git",
            exact: "3.17.3"
        ),
    ],
    targets: [
        .target(
            name: "BroadCore",
            dependencies: [
                .product(name: "Swinject", package: "Swinject"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "BroadMonetization",
            dependencies: [
                "BroadCore",
                .product(name: "Swinject", package: "Swinject"),
                .product(
                    name: "Adapty",
                    package: "AdaptySDK-iOS",
                    condition: .when(platforms: [.iOS])
                ),
            ]
        ),
        .target(
            name: "BroadUIFlows",
            dependencies: [
                "BroadCore",
                "BroadMonetization",
                .product(name: "Swinject", package: "Swinject"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
