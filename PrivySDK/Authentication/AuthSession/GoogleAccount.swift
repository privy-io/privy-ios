import Foundation

/// A Google account created via Google Sign-In
public struct GoogleAccount: Sendable {
    /// ID of the Google user
    public let subject: String
    /// Email associated to the Google user
    public let email: String
    /// Name associated to the Google user
    public let name: String?
    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension GoogleOAuthAccountResponse {
    func toGoogleAccount() -> GoogleAccount {
        return GoogleAccount(
            subject: subject,
            email: email,
            name: name,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
