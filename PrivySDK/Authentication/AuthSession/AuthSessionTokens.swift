import Foundation

internal struct AuthSessionTokens: Codable, Sendable {
    internal let authToken: String
    internal let refreshToken: String
    internal let identityToken: String?
    internal let loginMethod: LoginMethod
}

internal extension InternalAuthSession {
    func toAuthSessionTokens() -> AuthSessionTokens {
        return AuthSessionTokens(authToken: authToken, refreshToken: refreshToken, identityToken: identityToken, loginMethod: loginMethod)
    }
}
