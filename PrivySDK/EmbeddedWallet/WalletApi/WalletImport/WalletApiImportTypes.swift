import Foundation

/// The kind of entropy a wallet import carries.
internal enum WalletApiImportEntropyType: String, Encodable, Sendable {
    /// A raw private key
    case privateKey = "private-key"
    /// A BIP-39 seed phrase, imported at a given HD index
    case hd = "hd"
}

/// How the entropy is encrypted for the wallet import enclave.
internal enum WalletApiImportEncryptionType: String, Encodable, Sendable {
    case hpke = "HPKE"
}
