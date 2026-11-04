import Foundation

/// External wallet used to login
public struct ExternalWallet: Sendable {
    /// The wallet address
    public let address: String

    /// The chain of the wallet, i.e. "ethereum" or "solana"
    public let chainType: ChainType

    /**
     * Represents the CAIP-2 formatted chain ID of the wallet
     * during the most recent verification during SIWE. May not
     * be up to date with the current chain ID of the wallet.
     *
     * e.g. eip155:1, eip155:5, eip155:137, etc.
     */
    public let chainId: String?

    /**
     * The wallet client used for this wallet during the most recent verification.
     * Values include but are not limited to `metamask`, `rainbow`, `coinbase_wallet`, etc.
     */
    public let walletClientType: String?

    /**
     * The connector type used for this wallet during the most recent verification.
     *
     * This includes but is not limited to `injected`, `wallet_connect`, `coinbase_wallet`, `embedded`.
     */
    public let connectorType: String?

    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension WalletAccountResponse {
    func toExternalWallet() -> ExternalWallet {
        return ExternalWallet(
            address: address,
            chainType: ChainType(chainType: chainType),
            chainId: chainId,
            walletClientType: walletClientType,
            connectorType: connectorType,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
