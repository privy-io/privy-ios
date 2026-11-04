import Foundation

/// Represents the embedded wallet mode configuration
internal enum EmbeddedWalletMode: String, Decodable {
    /// Only iframe-backed embedded wallets are allowed
    case legacyEmbeddedWalletsOnly = "legacy-embedded-wallets-only"
    /// Only user-controlled server wallets are allowed
    case userControlledServerWalletsOnly = "user-controlled-server-wallets-only"
}

/// Configurations related to embedded wallets
internal struct EmbeddedWalletConfig: Decodable {
    /// The mode of embedded wallets allowed in the app
    internal let mode: EmbeddedWalletMode
}

internal struct AppConfig: Decodable {
    internal let embeddedWalletConfig: EmbeddedWalletConfig

    private enum CodingKeys: String, CodingKey {
        case embeddedWalletConfig = "embedded_wallet_config"
    }
}
