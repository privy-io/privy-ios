import Foundation

internal protocol EmbeddedWalletAccount: Sendable {
    /// The id of the wallet in the wallets api
    var id: String? { get }

    /** The embedded wallet address _(`0x...`)_ */
    var address: String { get }

    /**
     * The chain of the wallet, i.e. "ethereum" or "solana"
     */
    var chainType: ChainType { get }

    /**
     * If this is a 'privy' embedded wallet, stores the recovery method:
     *
     *     1. 'privy' or 'privy-v2': privy escrow of the recovery material
     *     2. 'user-passcode': recovery protected by user-input passcode
     */
    var recoveryMethod: String? { get }

    /// Date when the account was first verified
    var firstVerifiedAt: Date? { get }

    /// Latest date when the account was verified
    var latestVerifiedAt: Date? { get }

    /** The wallet index used to detemine the index of user's additional wallets . */
    var hdWalletIndex: Int { get }

    /// Whether the wallet was imported
    var imported: Bool { get }

    /// Whether the user can unilaterally sign with this wallet
    var userCanSign: Bool { get }
}

internal extension EmbeddedWalletAccount {
    // Generic term for "wallet address" on Ethereum or "public key" on Solana
    var entropyId: String { address }

    // Source of the `entropyId` property.
    // ethereum-address-verifier: the entropyId is the address of the Ethereum wallet derived
    // at index 0 for this entropy
    // solana-address-verifier: the entropyId is a the address of the Solana wallet derived
    // at index 0 for this entropy
    var entropyIdVerifier: String {
        switch chainType {
        case .ethereum: "ethereum-address-verifier"
        case .solana: "solana-address-verifier"
        }
    }

    /// Whether the wallet belongs to the TEE stack
    var isTEEWallet: Bool { recoveryMethod == "privy-v2" && id != nil }
}
