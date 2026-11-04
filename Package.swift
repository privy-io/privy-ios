// swift-tools-version: 6.0
// Source manifest for PrivySDK. It is exported unchanged to the public
// privy-io/privy-ios `swift-source` branch, and CI uses it for API checks. The XCFramework
// is still built from PrivySDK.xcodeproj. Keep the Factory requirement in step with the
// project's package reference.

import PackageDescription

let package = Package(
    name: "PrivySDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PrivySDK", targets: ["PrivySDK"]),
        // The product name consumers of the public privy-io/privy-ios package depend on.
        .library(name: "Privy", targets: ["PrivySDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory", from: "2.5.3"),
    ],
    targets: [
        .target(
            name: "PrivySDK",
            dependencies: [
                .product(name: "FactoryKit", package: "Factory"),
            ],
            path: "PrivySDK",
            exclude: ["PrivySDK.h"]
        ),
    ]
)
