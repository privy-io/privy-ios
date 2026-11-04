import Foundation

internal struct WalletApiImportInitResponse: Decodable {
    /// The raw 65-byte uncompressed P-256 point to encrypt the entropy to.
    internal let encryptionPublicKey: Base64Data

    private enum CodingKeys: String, CodingKey {
        case encryptionPublicKey = "encryption_public_key"
    }
}
