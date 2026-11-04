import Foundation

// MARK: - LinkedAccount

internal enum LinkedAccountResponse {
    case customAuth(CustomAuthAccountResponse)
    case wallet(WalletAccountResponse)
    case email(EmailAccountResponse)
    case phone(PhoneNumberAccountResponse)
    case google(GoogleOAuthAccountResponse)
    case twitter(TwitterOAuthAccountResponse)
    case discord(DiscordOAuthAccountResponse)
    case apple(AppleOAuthAccountResponse)
    case telegram(TelegramOAuthAccountResponse)
    case passkey(PasskeyAccountResponse)
    case unknown
}

extension LinkedAccountResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "custom_auth":
            let data = try CustomAuthAccountResponse(from: decoder)
            self = .customAuth(data)
        case "wallet":
            let data = try WalletAccountResponse(from: decoder)
            self = .wallet(data)
        case "email":
            let emailAccount = try EmailAccountResponse(from: decoder)
            self = .email(emailAccount)
        case "phone":
            let phoneNumberAccount = try PhoneNumberAccountResponse(from: decoder)
            self = .phone(phoneNumberAccount)
        case "google_oauth":
            let googleOAuthAccountResponse = try GoogleOAuthAccountResponse(from: decoder)
            self = .google(googleOAuthAccountResponse)
        case "twitter_oauth":
            let twitterOAuthAccountResponse = try TwitterOAuthAccountResponse(from: decoder)
            self = .twitter(twitterOAuthAccountResponse)
        case "discord_oauth":
            let discordOAuthAccountResponse = try DiscordOAuthAccountResponse(from: decoder)
            self = .discord(discordOAuthAccountResponse)
        case "apple_oauth":
            let appleOAuthAccountResponse = try AppleOAuthAccountResponse(from: decoder)
            self = .apple(appleOAuthAccountResponse)
        case "telegram":
            let telegramOAuthAccountResponse = try TelegramOAuthAccountResponse(from: decoder)
            self = .telegram(telegramOAuthAccountResponse)
        case "passkey":
            let passkeyAccountResponse = try PasskeyAccountResponse(from: decoder)
            self = .passkey(passkeyAccountResponse)
        default:
            self = .unknown
        }
    }
}

// MARK: - CustomAuth

/// Account created with an alternative auth provider _(Auth0 etc...)_
internal struct CustomAuthAccountResponse: Decodable {
    /** The user ID given by the custom auth provider */
    internal let customUserId: String
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    private enum CodingKeys: String, CodingKey {
        case customUserId = "custom_user_id"
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}

// MARK: - Wallet

/// Self custodial embedded wallet account _(created by Privy)_ OR external wallet used for sign in
internal struct WalletAccountResponse: Decodable {
    /// The id of the wallet in the wallets api
    internal let id: String?

    /** The embedded wallet address _(`0x...`)_ */
    internal let address: String

    // The chain type, currently either "ethereum" or "solana"
    internal let chainType: String

    /**
     * Represents the CAIP-2 formatted chain ID of the wallet
     * during the most recent verification during SIWE. May not
     * be up to date with the current chain ID of the wallet.
     *
     * Embedded wallets do not complete SIWE since the user is
     * already authenticated, and you should not use this field
     * for the embedded wallet.
     *
     * e.g. eip155:1, eip155:5, eip155:137, etc.
     */
    internal let chainId: String?

    /**
     * The wallet client used for this wallet during the most recent verification.
     *
     * If the value is `privy`, then this is a privy embedded wallet.
     *
     * Other values include but are not limited to `metamask`, `rainbow`, `coinbase_wallet`, etc.
     */
    internal let walletClientType: String?

    /**
     * The connector type used for this wallet during the most recent verification.
     *
     * This includes but is not limited to `injected`, `wallet_connect`, `coinbase_wallet`, `embedded`.
     */
    internal let connectorType: String?

    /**
     * If this is a 'privy' embedded wallet, stores the recovery method:
     *
     *     1. 'privy' or 'privy-v2': privy escrow of the recovery material
     *     2. 'user-passcode': recovery protected by user-input passcode
     */
    internal let recoveryMethod: String?

    /** Datetime when this account was linked to the user. */
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    /** The wallet index used to detemine the index of user's additional wallets . */
    internal let hdWalletIndex: Int?

    /// Whether the wallet was imported
    internal let imported: Bool?

    /// `user_can_sign` as sent by the API. Only external wallets omit it.
    internal let rawUserCanSign: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case address
        case chainId = "chain_id"
        case chainType = "chain_type"
        case walletClientType = "wallet_client_type"
        case connectorType = "connector_type"
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"

        case recoveryMethod = "recovery_method"
        case hdWalletIndex = "wallet_index"
        case imported
        case rawUserCanSign = "user_can_sign"
    }
}

internal extension WalletAccountResponse {
    /// Whether the user can unilaterally sign with this wallet. Always `true` for external wallets.
    var userCanSign: Bool { rawUserCanSign ?? true }

    func isPrivyWallet() -> Bool {
        return walletClientType == "privy" && connectorType == "embedded"
    }
}

// MARK: - Email

/// Account created via email
internal struct EmailAccountResponse: Decodable {
    internal let email: String
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    private enum CodingKeys: String, CodingKey {
        case email = "address"
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}

// MARK: - Email

/// Account created via phone number
internal struct PhoneNumberAccountResponse: Decodable {
    internal let phoneNumber: String
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    private enum CodingKeys: String, CodingKey {
        case phoneNumber
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}

// MARK: Google OAuth

// Account created via google oAuth
internal struct GoogleOAuthAccountResponse: Decodable {
    internal let subject: String
    internal let email: String
    internal let name: String?
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    private enum CodingKeys: String, CodingKey {
        case subject
        case email
        case name
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}

// MARK: Twitter OAuth

// Account created via Twitter oAuth
internal struct TwitterOAuthAccountResponse: Decodable {
    internal let subject: String
    internal let username: String?
    internal let name: String?
    internal let profilePictureUrl: String?
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    private enum CodingKeys: String, CodingKey {
        case subject
        case username
        case name
        case profilePictureUrl = "profile_picture_url"
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}

// MARK: Discord OAuth

// Account created via Discord oAuth
internal struct DiscordOAuthAccountResponse: Decodable {
    internal let subject: String
    internal let username: String?
    internal let email: String?
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    private enum CodingKeys: String, CodingKey {
        case subject
        case username
        case email
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}

// MARK: Apple OAuth

// Account created via apple oAuth
internal struct AppleOAuthAccountResponse: Decodable {
    internal let subject: String
    internal let email: String
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    private enum CodingKeys: String, CodingKey {
        case subject
        case email
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}

// MARK: Telegram OAuth

// Account created via Telegram oAuth
internal struct TelegramOAuthAccountResponse: Decodable {
    internal let telegramUserId: String
    internal let firstName: String?
    internal let lastName: String?
    internal let username: String?
    internal let photoUrl: String?
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    private enum CodingKeys: String, CodingKey {
        case telegramUserId = "telegram_user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case photoUrl = "photo_url"
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}

// MARK: Passkeys

internal struct PasskeyAccountResponse: Decodable {
    internal let credentialId: String
    internal let authenticatorName: String?
    internal let createdWithBrowser: String?
    internal let createdWithOs: String?
    internal let createdWithDevice: String?
    internal let publicKey: String?
    internal let enrolledInMfa: Bool
    internal let firstVerifiedAt: SecondsSinceEpoch?
    internal let latestVerifiedAt: SecondsSinceEpoch?

    // Use CodingKeys to map the JSON keys (SerialName in Kotlin)
    // to the Swift property names.
    private enum CodingKeys: String, CodingKey {
        case credentialId = "credential_id"
        case authenticatorName = "authenticator_name"
        case createdWithBrowser = "created_with_browser"
        case createdWithOs = "created_with_os"
        case createdWithDevice = "created_with_device"
        case publicKey = "public_key"
        case enrolledInMfa = "enrolled_in_mfa"
        case firstVerifiedAt = "first_verified_at"
        case latestVerifiedAt = "latest_verified_at"
    }
}
