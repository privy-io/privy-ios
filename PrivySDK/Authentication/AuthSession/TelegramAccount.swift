import Foundation

/// Account created via Login with Telegram
public struct TelegramAccount: Sendable {
    /// ID of the Telegram user
    public let telegramUserId: String
    /// First name of the Telegram user
    public let firstName: String?
    /// Last name of the Telegram user
    public let lastName: String?
    /// Username associated to the Telegram user
    public let username: String?
    /// URL of profile photo associated to the Telegram user
    public let photoUrl: String?
    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension TelegramOAuthAccountResponse {
    func toTelegramAccount() -> TelegramAccount {
        return TelegramAccount(
            telegramUserId: telegramUserId,
            firstName: firstName,
            lastName: lastName,
            username: username,
            photoUrl: photoUrl,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
