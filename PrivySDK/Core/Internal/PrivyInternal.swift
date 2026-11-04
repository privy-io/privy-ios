// swiftlint:disable missing_docs
public class PrivyInternal {
    private static let KEY_PLATFORM = "platform"
    private static let KEY_VERSION = "version"

    nonisolated(unsafe) internal static var settings: PrivyInternalSettings?

    @available(*, deprecated, message: "Use setConfig(platform:sdkVersion:) instead. Will be removed in a future major release.")
    public static func setConfig(config: [String: String]) {
        guard let platform = config[KEY_PLATFORM], let version = config[KEY_VERSION] else {
            return
        }

        settings = PrivyInternalSettings(platform: platform, sdkVersion: version)
    }

    /// Reserved for Privy's own platform wrapper SDKs (e.g. flutter-sdk) to report their
    /// platform/version to Privy's backend via the `privy-client` header. Gated by the
    /// `PrivyFlutterBridge` SPI, so it is invisible to normal public API consumers — only
    /// files that `@_spi(PrivyFlutterBridge) import PrivySDK` can call it.
    @_spi(PrivyFlutterBridge)
    public static func setConfig(platform: String, sdkVersion: String) {
        settings = PrivyInternalSettings(platform: platform, sdkVersion: sdkVersion)
    }
}

internal struct PrivyInternalSettings {
    internal let platform: String
    internal let sdkVersion: String
}
