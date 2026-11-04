import Foundation

internal struct RefreshUserResponse {
    internal let user: UserResponse
    internal let identityToken: String?
}

extension RefreshUserResponse: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case user
        case identityToken = "identity_token"
    }
}
