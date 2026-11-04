import Foundation

/// Account created via email
public struct EmailAccount: Sendable {
    /// The email address of the account
    public let email: String
    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension EmailAccountResponse {
    func toEmailAccount() -> EmailAccount {
        return EmailAccount(
            email: email,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
