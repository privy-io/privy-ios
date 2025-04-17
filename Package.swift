// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Privy",
    platforms: [
        .iOS(.v16),
        .macOS(.v11),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Privy",
            targets: ["PrivySDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory.git", .upToNextMajor(from: "2.4.3"))
    ],
    targets: [
        .binaryTarget(
            name: "PrivySDK",
            path: "PrivySDK.xcframework"),
    ]
)
