import Foundation

/// Embedded ethereum wallet account _(created by Privy)_
public struct EmbeddedEthereumWalletAccount: EmbeddedWalletAccount {
    /// The id of the wallet in the wallets api
    public let id: String?

    /// The embedded wallet address, hex encoded _(`0x...`)_
    public let address: String

    /// The chain of the wallet, i.e. "ethereum"
    public let chainType: ChainType = .ethereum

    /**
     * The recovery method of the embedded wallet
     * - "privy" or "privy-v2": privy escrow of the recovery material
     * - "user-passcode": recovery protected by user-input passcode
     */
    public let recoveryMethod: String?

    /// Date when the account was first verified
    public let firstVerifiedAt: Date?

    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?

    /// The hierarchical deterministic (HD) index of this wallet: its position in its seed phrase's
    /// derivation path.
    ///
    /// Not unique: wallets derived from different seed phrases can share an index, and imported
    /// private keys report 0. Use ``id`` or ``address`` to identify a wallet.
    ///
    /// In apps that use TEE execution, Privy assigns this. It isn't necessarily one more than the
    /// user's current wallet count, and indices can have gaps. For an imported wallet, it's the
    /// index it was imported at, or 0 for a private key.
    public let hdWalletIndex: Int

    /// Whether the wallet was imported (e.g. from a private key or a seed phrase).
    public let imported: Bool

    /// Whether the user can unilaterally sign with this wallet
    public let userCanSign: Bool
}

internal extension WalletAccountResponse {
    func toEmbeddedEthereumWalletAccount() -> EmbeddedEthereumWalletAccount {
        EmbeddedEthereumWalletAccount(
            id: id,
            address: address,
            recoveryMethod: recoveryMethod,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date,
            hdWalletIndex: hdWalletIndex ?? 0,
            imported: imported ?? false,
            userCanSign: userCanSign
        )
    }
}
