import Foundation

internal struct WalletAuthenticateRequest: Encodable {
    internal let userJwt: String
    internal let encryptionType: String
    internal let recipientPublicKey: String

    private enum CodingKeys: String, CodingKey {
        case userJwt = "user_jwt"
        case encryptionType = "encryption_type"
        case recipientPublicKey = "recipient_public_key"
    }
}
