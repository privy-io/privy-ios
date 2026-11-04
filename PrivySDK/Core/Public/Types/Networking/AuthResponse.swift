import Foundation

/// The user object representing an authenticated user
internal struct AuthResponse: Sendable {
    internal let user: UserResponse
    internal let token: String?
    internal let refreshToken: String?
    internal let identityToken: String?
    internal let sessionUpdateAction: SessionUpdateAction
}

extension AuthResponse: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case user
        case token
        case refreshToken = "refresh_token"
        case identityToken = "identity_token"
        case sessionUpdateAction = "session_update_action"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(UserResponse.self, forKey: .user)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        identityToken = try container.decodeIfPresent(String.self, forKey: .identityToken)

        let action = try container.decode(String.self, forKey: .sessionUpdateAction)
        switch action {
        case "set":
            // "set" requires both access and refresh tokens to be present.
            // If either is missing, treat as a server error and fall back to clear.
            if let token, let refreshToken {
                sessionUpdateAction = .set(
                    accessToken: token,
                    refreshToken: refreshToken,
                    identityToken: identityToken
                )
            } else {
                sessionUpdateAction = .clear
            }
        case "clear":
            sessionUpdateAction = .clear
        case "ignore":
            // "ignore" may or may not include tokens — e.g. concurrent rotation returns
            // a fresh access token but no refresh token. Pass whatever is present.
            sessionUpdateAction = .ignore(accessToken: token, refreshToken: refreshToken, identityToken: identityToken)
        default:
            sessionUpdateAction = .clear
        }
    }
}

internal enum SessionUpdateAction: Sendable {
    case set(accessToken: String, refreshToken: String, identityToken: String?)
    case clear
    case ignore(accessToken: String?, refreshToken: String?, identityToken: String?)

    internal var shouldEvictFromCache: Bool {
        switch self {
        case .ignore, .clear:
            return true
        case .set:
            return false
        }
    }
}
