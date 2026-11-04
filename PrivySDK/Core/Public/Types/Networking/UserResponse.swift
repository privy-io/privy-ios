import Foundation

// MARK: - User

internal struct UserResponse {
    internal let id: String
    internal let createdAt: SecondsSinceEpoch
    internal let linkedAccounts: [LinkedAccountResponse]
    internal let mfaMethods: [MfaMethodResponse]
}

extension UserResponse: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case linkedAccounts = "linked_accounts"
        case mfaMethods = "mfa_methods"
    }
}
