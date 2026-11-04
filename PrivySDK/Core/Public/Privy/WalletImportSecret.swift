import Foundation

/// The secret of an existing wallet to import with
/// ``PrivyUser/importWallet(chainType:address:secret:)``.
///
/// The secret is never included in the value's description, so printing or logging a
/// `WalletImportSecret` does not reveal it.
public enum WalletImportSecret: Sendable {
    /// A raw private key, as bytes.
    ///
    /// - For Ethereum: the 32-byte secp256k1 private key. Decode a hex-encoded key before passing it.
    /// - For Solana: the 64-byte secret key (the 32-byte seed followed by the public key, as exported
    ///   by wallets such as Phantom) or the 32-byte seed. Decode a base58-encoded key before passing it.
    ///
    /// The imported wallet reports an ``EmbeddedWallet/hdWalletIndex`` of 0. Privy never uses an
    /// imported private key to derive new wallets.
    case privateKey(Data)

    /// A seed phrase, and the index of the wallet to import from it.
    ///
    /// The wallet at `index` of the standard derivation path is imported: `m/44'/60'/0'/0/{index}`
    /// for Ethereum and `m/44'/501'/{index}'/0'` for Solana. Pass `0` for the wallet most wallets
    /// show first.
    ///
    /// The phrase is sent as given: a BIP-39 English seed phrase, with its words separated by single
    /// spaces. BIP-39 passphrases are not supported.
    ///
    /// The imported wallet keeps `index` as its ``EmbeddedWallet/hdWalletIndex``. Privy assigns the
    /// indices of wallets it later derives from the phrase.
    ///
    /// > Warning: Importing a seed phrase can also make it the source of wallets Privy creates for
    /// > this user later, on any chain. Anyone who holds the phrase can derive those wallets too.
    /// > Only import seed phrases the user controls and hasn't shared.
    case mnemonic(String, index: Int)
}

extension WalletImportSecret: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// A redacted description that names the kind of secret without revealing it.
    public var description: String {
        switch self {
        case .privateKey:
            "WalletImportSecret.privateKey(<redacted>)"
        case .mnemonic:
            "WalletImportSecret.mnemonic(<redacted>)"
        }
    }

    /// A redacted description that names the kind of secret without revealing it.
    public var debugDescription: String {
        description
    }

    /// A mirror with no children, so `dump` and debuggers don't reveal the secret.
    public var customMirror: Mirror {
        Mirror(self, children: [], displayStyle: .enum)
    }
}

internal extension WalletImportSecret {
    /// The kind of entropy the import endpoints expect for this secret.
    var entropyType: WalletApiImportEntropyType {
        switch self {
        case .privateKey: .privateKey
        case .mnemonic: .hd
        }
    }

    /// The HD index of the wallet to import, only set for seed phrases.
    var index: Int? {
        switch self {
        case .privateKey: nil
        case .mnemonic(_, let index): index
        }
    }

    /// The bytes to encrypt for the import enclave: the raw private key, or the UTF-8 bytes of the
    /// seed phrase.
    var plaintext: Data {
        switch self {
        case .privateKey(let privateKey): privateKey
        case .mnemonic(let mnemonic, _): Data(mnemonic.utf8)
        }
    }
}
