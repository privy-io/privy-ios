# Privy iOS SDK

The Privy Swift SDK is a Swift library client for Privy that allows you to add secure authentication, non-custodial embedded wallets, and powerful user management into your iOS application.

## Installation

Add the package in Xcode (File → Add Package Dependencies…) or in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/privy-io/privy-ios", from: "<version>"),
],
targets: [
    .target(name: "YourApp", dependencies: [.product(name: "Privy", package: "privy-ios")]),
]
```

Requires iOS 17+ or macOS 14+.

## Usage

See Privy's [iOS SDK guide](https://docs.privy.io/basics/swift/quickstart) for setup and usage.

## License

Released under the [MIT License](LICENSE).
