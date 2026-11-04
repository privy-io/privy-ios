import Foundation

/// Account created via Login with X
public struct TwitterAccount: Sendable {
    /// ID of the Twitter user
    public let subject: String
    /// Username associated to the Twitter user
    public let username: String?
    /// Name associated to the Twitter user
    public let name: String?
    /// URL of profile picture associated to the Twitter user
    public let profilePictureUrl: String?
    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension TwitterOAuthAccountResponse {
    func toTwitterAccount() -> TwitterAccount {
        return TwitterAccount(
            subject: subject,
            username: username,
            name: name,
            profilePictureUrl: profilePictureUrl,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
