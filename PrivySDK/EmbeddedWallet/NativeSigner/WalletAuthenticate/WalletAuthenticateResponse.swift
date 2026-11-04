import Foundation

internal struct WalletAuthenticateResponse: Decodable {
    internal let encryptedAuthorizationKey: EncryptedAuthorizationKey
    internal let expiresAt: Int

    internal struct EncryptedAuthorizationKey: Decodable {
        internal let encryptionType: String
        internal let encapsulatedKey: String
        internal let ciphertext: String

        private enum CodingKeys: String, CodingKey {
            case encryptionType = "encryption_type"
            case encapsulatedKey = "encapsulated_key"
            case ciphertext
        }
    }

    private enum CodingKeys: String, CodingKey {
        case encryptedAuthorizationKey = "encrypted_authorization_key"
        case expiresAt = "expires_at"
    }
}
