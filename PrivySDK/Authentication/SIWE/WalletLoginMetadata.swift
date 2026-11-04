import Foundation

/// Additional metadata specifying wallet client and connector type, for use during wallet login or linking.
public struct WalletLoginMetadata: Sendable {
    /// (Optional) The wallet type, e.g. WalletClient.metamask or WalletClient.other if not listed
    internal let walletClientType: WalletClientType?

    /// (Optional) The wallet connector, e.g. "wallet_connect"
    internal let connectorType: String?

    /// Create metadata for use in wallet login
    public init(walletClientType: WalletClientType?, connectorType: String?) {
        self.walletClientType = walletClientType
        self.connectorType = connectorType
    }
}
