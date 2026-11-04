import Foundation

// MARK: - TOTP Models

/// Response from `/api/v1/mfa/totp/init`
internal struct TotpInitResponse: Decodable {
    internal let totpSecret: String
    internal let totpAuthUrl: String
}

/// Request body for `/api/v1/mfa/totp/enroll` and `/api/v1/mfa/totp/verify`
internal struct TotpCodeRequest: Encodable {
    internal let code: String
}
