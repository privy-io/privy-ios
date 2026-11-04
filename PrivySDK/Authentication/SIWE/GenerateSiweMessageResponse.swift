import Foundation

internal struct GenerateSiweMessageResponse: Decodable {
    internal let nonce: String
    internal let address: String
    internal let expiresAt: String

    private enum CodingKeys: String, CodingKey {
        case nonce
        case address
        case expiresAt = "expires_at"
    }
}
