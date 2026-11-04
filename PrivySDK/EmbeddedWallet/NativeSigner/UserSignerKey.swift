import Foundation

internal struct UserSignerKey: Codable, Sendable {
    internal let privateKeyBase64: String

    /// Expiration timestamp in milliseconds since epoch (from backend's Date.getTime())
    internal let expiresAtMs: Int
}
