import Foundation

/// Account created via Sign in with Apple
public struct AppleAccount: Sendable {
    /// ID of the Apple user
    public let subject: String
    /// Email associated to the Apple user
    public let email: String
    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension AppleOAuthAccountResponse {
    func toAppleAccount() -> AppleAccount {
        return AppleAccount(
            subject: subject,
            email: email,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
