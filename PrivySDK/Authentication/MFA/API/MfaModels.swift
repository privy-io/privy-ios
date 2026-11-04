import Foundation

// MARK: - Common Response Models

/// Response from verify endpoints that return an MFA token
internal struct MfaVerifyResponse: Decodable {
    internal let token: String
}
