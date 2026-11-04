import Foundation

/// An embedded wallet that you can operate on
public protocol EmbeddedWallet: Sendable {
    /// The ID of the wallet in the Privy wallets API. Use it or ``address`` to identify the wallet.
    /// Can be `nil` for on-device wallets.
    var id: String? { get }

    /// The embedded wallet address
    var address: String { get }
    /**
     * The recovery method of the embedded wallet
     * - "privy" or "privy-v2": privy escrow of the recovery material
     * - "user-passcode": recovery protected by user-input passcode
     */
    var recoveryMethod: String? { get }
    /// The hierarchical deterministic (HD) index of this wallet: its position in its seed phrase's
    /// derivation path.
    ///
    /// Not unique: wallets derived from different seed phrases can share an index, and imported
    /// private keys report 0. Use ``id`` or ``address`` to identify a wallet.
    ///
    /// In apps that use TEE execution, Privy assigns this. It isn't necessarily one more than the
    /// user's current wallet count, and indices can have gaps. For an imported wallet, it's the
    /// index it was imported at, or 0 for a private key.
    var hdWalletIndex: Int { get }
    /// The chain of the wallet, i.e. "ethereum" or "solana"
    var chainType: ChainType { get }
    /// Whether the wallet was imported (e.g. from a private key or a seed phrase).
    var imported: Bool { get }
    /// Whether the user can unilaterally sign with this wallet
    var userCanSign: Bool { get }

    /// Adds additional signers to this wallet.
    ///
    /// The new signers are merged with any existing signers on the wallet.
    /// After success, the user data is automatically refreshed.
    ///
    /// Only TEE wallets support adding signers.
    ///
    /// - Parameters:
    ///   - signers: The signers to add to this wallet.
    ///
    /// - Throws: ``PrivyError`` if the wallet is not on the TEE stack.
    func addSigners(_ signers: [SignerInput]) async throws

    /// Removes a signer from this wallet by its ID.
    ///
    /// Fetches the current signers, filters out the one matching `signerId`,
    /// and updates the wallet with the remaining signers.
    /// After success, the user data is automatically refreshed.
    ///
    /// Only TEE wallets support removing signers.
    ///
    /// - Parameters:
    ///   - signerId: The identifier of the signer to remove.
    ///
    /// - Throws: ``PrivyError`` if the wallet is not on the TEE stack.
    func removeSigner(signerId: String) async throws

    /// Removes all signers from this wallet.
    ///
    /// Updates the wallet with an empty signers list.
    /// After success, the user data is automatically refreshed.
    ///
    /// Only TEE wallets support removing signers.
    ///
    /// - Throws: ``PrivyError`` if the wallet is not on the TEE stack.
    func removeAllSigners() async throws

    /// Fetches paginated transaction history for this wallet.
    ///
    /// Only TEE wallets support fetching transactions.
    ///
    /// - Parameters:
    ///   - params: Query parameters including chain, asset/token filter, limit, and cursor.
    ///
    /// - Returns: A page of transactions with an optional cursor for the next page.
    /// - Throws: ``PrivyError`` if the wallet is not on the TEE stack or the request fails.
    func getTransactions(_ params: GetTransactionsParams) async throws -> TransactionsPage
}

public extension EmbeddedWallet {
    /// Defaults to `true` for conformers that don't provide it
    var userCanSign: Bool { true }

    /// Convenience method to add a single signer to this wallet.
    ///
    /// - Parameters:
    ///   - signer: The signer to add.
    ///
    /// - Throws: ``PrivyError`` if the wallet is not on the TEE stack.
    func addSigner(_ signer: SignerInput) async throws {
        try await addSigners([signer])
    }
}

internal extension EmbeddedWallet {
    /// Whether this wallet is on the TEE stack and supports signer management.
    var isTEEWallet: Bool { recoveryMethod == "privy-v2" && id != nil }
}
