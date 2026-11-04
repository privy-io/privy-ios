import Foundation
internal import FactoryKit

internal final class PrivyImpl: Privy, Sendable {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let internalAuthStateManager: InternalAuthStateManager = resolve(\PrivyContainer.internalAuthStateManager)
    private let logger: Logger = resolve(\PrivyContainer.logger)
    private let networkMonitor: NetworkMonitor = resolve(\PrivyContainer.networkMonitor)

    // Even though these aren't explicitly used in PrivyImpl, initialize them to kick off proactive work
    private let webViewAppLifecycleManager: WebViewAppLifecycleManager = resolve(\PrivyContainer.webViewAppLifecycleManager)
    private let analyticsManager: AnalyticsManager = resolve(\PrivyContainer.analyticsManager)
    private let embeddedWallet: EmbeddedWalletManager = resolve(\PrivyContainer.embeddedWalletManager)
    private let appConfigRepository: AppConfigRepository = resolve(\PrivyContainer.appConfigRepository)

    internal init() {
        setupNetworkConnectivityListener()
    }

    public var user: PrivyUser? {
        guard let _ = try? authManager.ensureAuthenticated() else { return nil }
        return PrivyContainer.shared.privyUser()
    }

    public var authState: AuthState {
        internalAuthStateManager.state.toPublicAuthState()
    }

    public func getAuthStateWithoutRefresh() -> AuthState {
        internalAuthStateManager.state.toPublicAuthState()
    }

    public var authStateStream: AsyncStream<AuthState> {
        get {
            AsyncStream { continuation in
                let task = Task {
                    for await authState in internalAuthStateManager.stateStream.map({ $0.toPublicAuthState() }) {
                        continuation.yield(authState)
                    }
                }

                continuation.onTermination = { continuation in
                    task.cancel()
                }
            }
        }
    }

    /// Entry point for login with email flow
    public let email: LoginWithEmail = resolve(\PrivyContainer.loginWithEmail)

    /// Entry point for login with SMS flow
    public let sms: LoginWithSms = resolve(\PrivyContainer.loginWithSms)

    /// Entry point for SIWE flow
    public let siwe: LoginWithSiwe = resolve(\PrivyContainer.loginWithSiwe)

    /// Entry point for SIWS flow
    public let siws: LoginWithSiws = resolve(\PrivyContainer.loginWithSiws)

    /// Entry point for login with custom access token flow
    public let customJwt: LoginWithCustomAccessToken = resolve(\PrivyContainer.loginWithCustomAccessToken)

    /// Entry point for OAuth flow
    public let oAuth: LoginWithOAuth = resolve(\PrivyContainer.loginWithOAuth)

    /// Entry point for passkey authentication flow
    public let passkey: LoginWithPasskey = resolve(\PrivyContainer.loginWithPasskey)

    /// Entry point for MFA operations
    public let mfa: PrivyMfa = resolve(\PrivyContainer.privyMfa)

    private let readyStateHandler: PrivyReadyStateHandler = resolve(\PrivyContainer.privyReadyStateHandler)

    /// Refresh existing session
    public func refreshSession() async throws -> PrivyUser {
        let _ = try await authManager.refreshSessionIfNeeded()
        return PrivyContainer.shared.privyUser()
    }

    private func refreshUser() async throws -> InternalPrivyUser {
        // TODO: Move this to the privy.user.refresh method instead
        return try await authManager.refreshUser()
    }

    // This is now deprecated. We can make it private after we remove it from the public API
    public func awaitReady() async {
        await readyStateHandler.awaitReady()
    }

    public func getAuthState() async -> AuthState {
        // Ensure initialization flow complete before returning the state
        await awaitReady()

        // Directly grab the value from internal auth state flow as it will be the most up to date
        return internalAuthStateManager.state.toPublicAuthState()
    }

    public func getUser() async -> (any PrivyUser)? {
        // async getAuthState call ensures awaitReady was called under the hood
        let authState = await getAuthState()

        return if case let .authenticated(privyUser) = authState {
            privyUser
        } else {
            nil
        }
    }

    public func onNetworkRestored() async {
        guard case .authenticatedUnverified(let authenticatedUnverifiedContext) = authState else {
            // No-op in all other cases
            return
        }

        await authManager.restoreSession()
    }

    private func setupNetworkConnectivityListener() {
        Task {
            var wasConnected = true

            for await isConnected in networkMonitor.connectivityStream {
                // Only trigger onNetworkRestored when transitioning from disconnected to connected
                if !wasConnected && isConnected {
                    logger.debug("Network connectivity restored, calling onNetworkRestored")
                    await onNetworkRestored()
                }

                // Print out network update if different than last one
                if (wasConnected != isConnected) {
                    logger.verbose("Network connectivity changed: \(isConnected ? "connected" : "disconnected")")
                }

                wasConnected = isConnected
            }
        }
    }
}

fileprivate extension InternalAuthState {
    func toPublicAuthState() -> AuthState {
        switch self {
        case .notReady:
            return AuthState.notReady
        case .authenticatedUnverified(let context):
            return AuthState.authenticatedUnverified(context)
        case .unauthenticated:
            return AuthState.unauthenticated
        case .authenticated:
            return AuthState.authenticated(PrivyContainer.shared.privyUser())
        }
    }
}
