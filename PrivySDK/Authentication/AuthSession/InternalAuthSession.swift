import Foundation

internal struct InternalAuthSession: Sendable {
    internal let user: InternalPrivyUser
    internal let authToken: String
    internal let refreshToken: String
    internal let identityToken: String?
    internal let loginMethod: LoginMethod
}

internal extension InternalAuthSession {
    // Returns a copy of the existing auth session, only updating the set parameters
    // This returns a new instance of InternalAuthSession, does not update the existing one in place
    func copy(user: InternalPrivyUser? = nil, identityToken: String? = nil) -> InternalAuthSession {
        return InternalAuthSession(
            user: user ?? self.user,
            authToken: authToken,
            refreshToken: refreshToken,
            identityToken: identityToken ?? self.identityToken,
            loginMethod: loginMethod
        )
    }
}
