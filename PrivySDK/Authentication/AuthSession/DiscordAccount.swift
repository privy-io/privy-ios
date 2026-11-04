import Foundation

/// Account created via Login with Discord
public struct DiscordAccount: Sendable {
    /// ID of the Discord user
    public let subject: String
    /// Username associated to the Discord user
    public let username: String?
    /// Email associated to the Discord user
    public let email: String?
    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension DiscordOAuthAccountResponse {
    func toDiscordAccount() -> DiscordAccount {
        return DiscordAccount(
            subject: subject,
            username: username,
            email: email,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
