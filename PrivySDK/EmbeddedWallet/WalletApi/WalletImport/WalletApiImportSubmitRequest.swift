import Foundation

/// The init response's `import_id` is deliberately not part of this request: the server rejects it
/// unless the app imports wallets without an address, which this SDK never does. The pending import
/// is found by its address instead.
internal struct WalletApiImportSubmitRequest: Encodable {
    internal let wallet: Wallet

    internal struct Wallet: Encodable {
        internal let address: String
        internal let chainType: WalletImportSupportedChainType
        internal let entropyType: WalletApiImportEntropyType
        internal let encryptionType: WalletApiImportEncryptionType
        /// The HD index, only sent for `hd` imports.
        internal let index: Int?
        /// The HPKE encapsulated key.
        internal let encapsulatedKey: Base64Data
        /// The HPKE-sealed entropy. The plaintext entropy is never part of this request.
        internal let ciphertext: Base64Data

        private enum CodingKeys: String, CodingKey {
            case address
            case chainType = "chain_type"
            case entropyType = "entropy_type"
            case encryptionType = "encryption_type"
            case index
            case encapsulatedKey = "encapsulated_key"
            case ciphertext
        }
    }
}
