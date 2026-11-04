import Foundation

internal enum InternalAuthState {
    case notReady
    case authenticatedUnverified(AuthState.AuthenticatedUnverifiedContext)
    case unauthenticated
    case authenticated(InternalAuthSession)

    internal var isConfirmedAuthenticated: Bool {
        switch self {
        case .authenticated:
            return true
        default:
            return false
        }
    }
}
