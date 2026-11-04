import Foundation

/// An enum representing the user's authentication state
public enum AuthState: Sendable {
    /// Auth state has not been determined yet. Call `Privy.awaitReady` to ensure auth state is set.
    case notReady

    /// Auth state cannot be determined while no network connectivity is available, but session tokens exist in cache.
    case authenticatedUnverified(AuthenticatedUnverifiedContext)

    /// The user is unauthenticated
    case unauthenticated

    /// The user is authenticated, which can be accessed via the associated value
    case authenticated(PrivyUser)

    public struct AuthenticatedUnverifiedContext: Sendable {
        // TODO: Introduce relevant data as "context" for the authenticatedUnverified auth state
    }
}
