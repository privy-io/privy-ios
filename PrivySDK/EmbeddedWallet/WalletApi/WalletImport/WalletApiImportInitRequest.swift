import Foundation

internal struct WalletApiImportInitRequest: Encodable {
    internal let address: String
    internal let chainType: WalletImportSupportedChainType
    internal let entropyType: WalletApiImportEntropyType
    internal let encryptionType: WalletApiImportEncryptionType
    /// The HD index, only sent for `hd` imports.
    internal let index: Int?

    private enum CodingKeys: String, CodingKey {
        case address
        case chainType = "chain_type"
        case entropyType = "entropy_type"
        case encryptionType = "encryption_type"
        case index
    }
}
