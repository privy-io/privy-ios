import Foundation

/// TOTP secret for authenticator app enrollment
public struct TotpSecret: Sendable {
    /// Raw secret for manual entry
    public let secret: String
    /// otpauth:// URL for QR code generation
    public let authUrl: String

    internal init(secret: String, authUrl: String) {
        self.secret = secret
        self.authUrl = authUrl
    }

    internal init(from response: TotpInitResponse) {
        self.secret = response.totpSecret
        self.authUrl = response.totpAuthUrl
    }
}
