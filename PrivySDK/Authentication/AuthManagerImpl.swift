import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var authManager: Factory<AuthManager> {
        self { AuthManagerImpl() }.shared
    }
}

private actor AuthManagerImpl: AuthManager {
    @Injected(\PrivyContainer.authRepository) private var authRepository: AuthRepository
    @Injected(\PrivyContainer.authRefreshService) private var authRefreshService: AuthRefreshService
    @Injected(\PrivyContainer.logger) private var logger: Logger
    @Injected(\PrivyContainer.config) private var config: PrivyConfig
    @Injected(\PrivyContainer.internalAuthStateManager) private var internalAuthStateManager: InternalAuthStateManager
    @Injected(\PrivyContainer.authSessionRepository) private var authSessionTokensRepository: AuthSessionTokensRepository
    @Injected(\PrivyContainer.mfaTokenRepository) private var mfaTokenRepository: MfaTokenRepository
    @LazyInjected(\PrivyContainer.walletMigrationManager) private var walletMigrationManager: WalletMigrationManager
    @Injected(\PrivyContainer.breadcrumbEmitter) private var breadcrumbEmitter: BreadcrumbEmitter

    fileprivate init() {
        // Try restoring session as soon Privy is initialized
        Task { [weak self] in
            guard let self else { return }
            await self.restoreSession()
        }
    }

    internal func sendOtp(to otpRequestType: OtpRequestType) async throws {
        return try await self.authRepository.sendOtp(to: otpRequestType)
    }

    internal func generateSiweMessage(walletAddress: String) async throws -> GenerateSiweMessageResponse {
        return try await self.authRepository.generateSiweMessage(walletAddress: walletAddress)
    }

    internal func generateSiwsMessage(for address: String) async throws -> SiwsInitResponseBody {
        return try await self.authRepository.siwsInit(.init(address: address))
    }

    internal func generateOAuthUrl(oAuthInitRequest: OAuthInitRequest) async throws -> OAuthInitResponse {
        return try await self.authRepository.generateOAuthUrl(oAuthInitRequest: oAuthInitRequest)
    }

    internal func generatePasskeyRegistrationOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions {
        return try await self.authRepository.generatePasskeyRegistrationOptions(relyingParty: relyingParty)
    }

    internal func generatePasskeyAuthenticationOptions(relyingParty: URL) async throws -> PasskeyAuthenticationApiOptions {
        return try await self.authRepository.generatePasskeyAuthenticationOptions(relyingParty: relyingParty)
    }

    internal func generatePasskeyLinkOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions {
        let auth = try await self.refreshSessionOrInvalidate()
        return try await self.authRepository.generatePasskeyLinkOptions(relyingParty: relyingParty, authToken: auth.authToken)
    }

    internal func linkPasskey(credential: PasskeyRegistrationCredential, relyingParty: String) async throws -> PrivyUser {
        let auth = try await self.refreshSessionOrInvalidate()

        let updatedUserResponse = try await self.authRepository.linkPasskey(
            credential: credential,
            relyingParty: relyingParty,
            authToken: auth.authToken
        )

        return try await self.updateSession(with: updatedUserResponse.toPrivyUser(), auth: auth)
    }

    func unlinkPasskey(credentialId: String, removeAsMfa: Bool = true) async throws -> PrivyUser {
        let auth = try await self.refreshSessionOrInvalidate()
        let mfaToken = await mfaTokenRepository.retrieve()

        let updatedUserResponse = try await self.authRepository.unlinkPasskey(
            credentialId: credentialId,
            removeAsMfa: removeAsMfa,
            authToken: auth.authToken,
            mfaToken: mfaToken
        )

        if removeAsMfa {
            await mfaTokenRepository.delete()
        }

        return try await self.updateSession(with: updatedUserResponse.toPrivyUser(), auth: auth)
    }

    internal func login(with loginType: LoginType) async throws -> PrivyUser {
        do {
            let authResponse = try await self.authRepository.authenticate(with: loginType)
            return try await self.updateSession(from: authResponse, by: loginType.toLoginMethod())
        } catch let backendError as AccountTransferBackendError {
            // Do NOT logout — the backend returned account_transfer_required during authenticate,
            // which means the caller was already authenticated and the backend entered an implicit
            // link path. The existing session must be preserved.
            throw backendError.toPrivyError()
        } catch {
            // An error on authenticate means the session is no longer a valid one
            internalAuthStateManager.update(state: .unauthenticated)
            // propagate error up
            throw error
        }
    }

    func loginWithSiws(address: String?, signing message: String, with signature: String, metadata: WalletLoginMetadata?) async throws -> PrivyUser {
        do {
            let authResponse = try await self.authRepository.siwsAuthenticate(
                SiwsAuthenticateRequestBody(
                    address: address,
                    connectorType: metadata?.connectorType,
                    message: message,
                    signature: signature,
                    walletClientType: metadata?.walletClientType?.rawValue,
                    messageType: .plain,
                    mode: .loginOrSignUp
                )
            )
            return try await self.updateSession(from: authResponse, by: .siws)
        } catch let backendError as AccountTransferBackendError {
            // Do NOT logout — the backend returned account_transfer_required during authenticate,
            // which means the caller was already authenticated and the backend entered an implicit
            // link path. The existing session must be preserved.
            throw backendError.toPrivyError()
        } catch {
            // An error on authenticate means the session is no longer a valid one
            internalAuthStateManager.update(state: .unauthenticated)
            // propagate error up
            throw error
        }
    }

    /// Update auth session with new one, which contains new user object
    private func updateSession(with user: InternalPrivyUser, auth: InternalAuthSession) async throws -> PrivyUser {
        try await self.setAuthSession(auth.copy(user: user))
        return PrivyContainer.shared.privyUser()
    }

    private func updateSession(from authResponse: AuthResponse, by loginMethod: LoginMethod) async throws -> PrivyUser {
        try await self.onAuthResponseReceived(
            authResponse: authResponse,
            loginMethod: loginMethod,
            existingSessionTokens: nil
        )
        return PrivyContainer.shared.privyUser()
    }

    internal func linkAccount(with loginType: LoginType) async throws -> PrivyUser {
        let auth = try await self.refreshSessionOrInvalidate()
        do {
            let updatedUserResponse = try await self.authRepository.link(with: loginType, authToken: auth.authToken)
            return try await self.updateSession(with: updatedUserResponse.toPrivyUser(), auth: auth)
        } catch let backendError as AccountTransferBackendError {
            throw backendError.toPrivyError()
        }
    }

    internal func transferAccount(with transferType: TransferType) async throws -> PrivyUser {
        let auth = try await self.refreshSessionOrInvalidate()
        do {
            let updatedUserResponse = try await self.authRepository.transfer(with: transferType, authToken: auth.authToken)
            return try await self.updateSession(with: updatedUserResponse.toPrivyUser(), auth: auth)
        } catch let backendError as AccountTransferBackendError {
            throw backendError.toPrivyError()
        }
    }

    internal func unlinkAccount(with unlinkType: UnlinkType) async throws -> PrivyUser {
        let auth = try await self.refreshSessionOrInvalidate()
        let updatedUserResponse = try await self.authRepository.unlink(with: unlinkType, authToken: auth.authToken)
        return try await self.updateSession(with: updatedUserResponse.toPrivyUser(), auth: auth)
    }

    internal func linkWithSiws(address: String?, signing message: String, with signature: String, metadata: WalletLoginMetadata?) async throws -> PrivyUser {
        let auth = try await self.refreshSessionOrInvalidate()
        do {
            let updatedUserResponse = try await self.authRepository.siwsLink(
                SiwsLinkRequestBody(
                    address: address,
                    connectorType: metadata?.connectorType,
                    message: message,
                    signature: signature,
                    walletClientType: metadata?.walletClientType?.rawValue,
                    messageType: .plain
                ),
                authToken: auth.authToken
            )
            return try await self.updateSession(with: updatedUserResponse.toPrivyUser(), auth: auth)
        } catch let backendError as AccountTransferBackendError {
            throw backendError.toPrivyError()
        }
    }

    internal func unlinkSiwsWallet(address: String) async throws -> PrivyUser {
        let auth = try await self.refreshSessionOrInvalidate()
        let updatedUserResponse = try await self.authRepository.siwsUnlink(
            SiwsUnlinkRequestBody(address: address),
            authToken: auth.authToken
        )
        return try await self.updateSession(with: updatedUserResponse.toPrivyUser(), auth: auth)
    }

    private func refreshSessionOrInvalidate() async throws -> InternalAuthSession {
        do {
            return try await self.refreshSession()
        } catch {
            // An error on refresh means the session is no longer a valid one
            internalAuthStateManager.update(state: .unauthenticated)
            throw error
        }
    }

    internal func updateEmail(to email: String, with code: String) async throws {
        let auth = try ensureAuthenticated()
        let accounts = auth.user.linkedAccounts

        guard let oldAddress = accounts.getEmailAccount()?.email else {
            throw PrivyError(.authenticationFailure(reason: .emailNotFound))
        }

        let updatedUserResponse = try await self.authRepository.updateEmail(from: oldAddress, to: email, with: code, authToken: auth.authToken)

        let updatedAuthSession = auth.copy(user: updatedUserResponse.toPrivyUser())
        try await self.setAuthSession(updatedAuthSession)
    }

    internal func updatePhoneNumber(to phoneNumber: String, with code: String) async throws {
        let auth = try ensureAuthenticated()
        let accounts = auth.user.linkedAccounts

        guard let oldPhoneNumber = accounts.getPhoneAccount()?.phoneNumber else {
            throw PrivyError(.authenticationFailure(reason: .phoneNotFound))
        }

        let updatedUserResponse = try await self.authRepository.updatePhoneNumber(from: oldPhoneNumber, to: phoneNumber, with: code, authToken: auth.authToken)

        let updatedAuthSession = auth.copy(user: updatedUserResponse.toPrivyUser())
        try await self.setAuthSession(updatedAuthSession)
    }

    /// Handles external refresh session request with precondition checks
    internal func refreshSession() async throws -> InternalAuthSession {
        let authSession = try ensureAuthenticated()

        return try await refreshSession(currentSession: authSession.toAuthSessionTokens())
    }

    internal func refreshSessionIfNeeded() async throws -> InternalAuthSession {
        let auth = try ensureAuthenticated()

        guard let authTokenJwt = auth.authToken.asJwt() else {
            throw PrivyError(.authenticationFailure(reason: .invalidJwt))
        }

        return if authTokenJwt.isExpired() {
            try await self.refreshSession()
        } else {
            auth
        }
    }

    internal func refreshUser() async throws -> InternalPrivyUser {
        let auth = try ensureAuthenticated()

        guard let authTokenJwt = auth.authToken.asJwt() else {
            throw PrivyError(.authenticationFailure(reason: .invalidJwt))
        }

        guard !authTokenJwt.isExpired() else {
            // Refreshing the session implicitly refreshes the user
            let session = try await self.refreshSession()
            return session.user
        }

        let refreshResponse = try await authRepository.refreshUser(token: auth.authToken)
        let refreshedUser = refreshResponse.user.toPrivyUser()

        internalAuthStateManager.update(state: .authenticated(auth.copy(user: refreshedUser, identityToken: refreshResponse.identityToken)))

        return refreshedUser
    }

    internal func logout() async {
        let currentState = internalAuthStateManager.state

        await authSessionTokensRepository.deleteAuthTokens()
        await mfaTokenRepository.delete()
        logger.info("Successfully deleted auth in keychain.")
        internalAuthStateManager.update(state: .unauthenticated)

        if case let .authenticated(session) = currentState {
            do {
                try await authRepository.logoutSession(authToken: session.authToken)
            } catch {
                logger.error("Failed to call /sessions/logout", error: error)
            }
        }
    }

    func restoreSession() async {
        guard let authSessionTokens = await authSessionTokensRepository.retrieveAuthTokens() else {
            logger.info("No session tokens found when attempting to restore session.")
            // If no valid auth tokens stored in keychain, set auth state to unauthenticated
            internalAuthStateManager.update(state: .unauthenticated)
            return
        }

        logger.info("Previous session exists. Attempting to restore.")
        breadcrumbEmitter.emit(.sessionRestoreStarted(loginMethod: authSessionTokens.loginMethod))

        do {
            let _ = try await self.refreshSession(currentSession: authSessionTokens)
            logger.debug("Successfully restored prior session.")
            breadcrumbEmitter.emit(.sessionRestoreCompleted(loginMethod: authSessionTokens.loginMethod))
        } catch {
            // RefreshSession internally handles authenticated state updates, so no need to here
            logger.error("Error restoring prior session: \(error.localizedDescription)", error: error)
            breadcrumbEmitter.emit(.sessionRestoreFailed(loginMethod: authSessionTokens.loginMethod, error: error))
        }
    }

    private func runAutomaticMigrationIfNeeded() async {
        guard !config.embeddedWalletConfig.disableAutomaticMigration else { return }
        do {
            try await walletMigrationManager.migrateWalletsIfNeeded()
        } catch {
            logger.error("Automatic wallet migration failed.", error: error)
        }
    }

    nonisolated func ensureAuthenticated() throws -> InternalAuthSession {
        let internalAuthStateManager: InternalAuthStateManager = resolve(\PrivyContainer.internalAuthStateManager)

        guard case let .authenticated(session) = internalAuthStateManager.state else {
            throw PrivyError(.authenticationFailure(reason: .notLoggedIn))
        }

        return session
    }

    /// Refresh the session.
    /// On success, set auth state to authenticated and store new session in keychain.
    /// On failure, set auth state to unauthentictead by delegating to logout and propagate error up
    private func refreshSession(currentSession: AuthSessionTokens) async throws -> InternalAuthSession {
        logger.info("Attempting to refresh session, via \(currentSession.loginMethod)")
        do {
            let session = switch currentSession.loginMethod {
            case .customAccessToken:
                // In the case of custom auth, we don't actually want to refresh
                // We want to get the latest custom auth token from client, and use that
                // to reauthenticate
                try await self.reauthenticateWithCustomAuth(currentSession: currentSession)
            case .email, .phone, .siwe, .siws, .oauth, .passkey:
                // For all other login types, refresh tokens with privy
                try await self.refreshTokensWithPrivy(currentSession: currentSession)
            }
            logger.debug("Session refreshed.")
            logger.verbose("Refreshed session loginMethod: \(session.loginMethod)")
            logger.verbose("Refreshed session authToken has content: \(!session.authToken.isEmpty)")
            logger.verbose("Refreshed session refreshToken has content: \(!session.refreshToken.isEmpty)")
            return session
        } catch {
            logger.error("Failed to refresh the session", error: error)
            if let urlError = error as? URLError, urlError.code.isConnectivityError {
                // If the reason for failure was related to connectivity, keep the session data
                internalAuthStateManager.update(state: .authenticatedUnverified(AuthState.AuthenticatedUnverifiedContext()))
                logger.warning("""
                A prior user session exists, but Privy cannot verify the authenticated state of the user \
                until network connectivity is restored. The auth state will remain "AuthenticatedUnverified" until \
                connectivity is restored, at which point Privy will automatically attempt to determine \
                the user's authenticated state. \
                Alternatively, you may call Privy.onNetworkRestored once you determine network is restored.
                """)
            } else if case .unauthenticated = internalAuthStateManager.state {
                // Already logged out (e.g. session expired server-side) — no-op
            } else {
                // If refresh fails, log user out and propagate error up
                await self.logout()
            }
            throw error
        }
    }

    private func reauthenticateWithCustomAuth(currentSession: AuthSessionTokens) async throws -> InternalAuthSession {
        // Get token from custom auth, then go through authenticate flow
        guard let customAuthTokenProvider = config.customAuthConfig?.tokenProvider else {
            throw PrivyError(.authenticationFailure(reason: .noCustomAuthProviderConfigured))
        }

        guard let token = try await customAuthTokenProvider() else {
            throw PrivyError(.authenticationFailure(reason: .customAuthProviderReturnedNoToken))
        }

        let _ = try await login(with: .customAccessToken(token: token))

        let authSession = try ensureAuthenticated()

        return authSession
    }

    private func refreshTokensWithPrivy(currentSession: AuthSessionTokens) async throws -> InternalAuthSession {
        let refreshedAuthResponse = try await self.authRefreshService.refreshAuth(authToken: currentSession.authToken, refreshToken: currentSession.refreshToken)

        return try await self.onAuthResponseReceived(
            authResponse: refreshedAuthResponse,
            loginMethod: currentSession.loginMethod,
            existingSessionTokens: currentSession
        )
    }

    /// Save a known-good session (used by link/unlink/update operations that always produce .set).
    private func setAuthSession(_ authSession: InternalAuthSession) async throws {
        try await authSessionTokensRepository.save(authTokens: authSession.toAuthSessionTokens())
        internalAuthStateManager.update(state: .authenticated(authSession))
        await runAutomaticMigrationIfNeeded()
    }

    /// Centralized handler for all auth responses based on session_update_action.
    @discardableResult
    private func onAuthResponseReceived(
        authResponse: AuthResponse,
        loginMethod: LoginMethod,
        existingSessionTokens: AuthSessionTokens?
    ) async throws -> InternalAuthSession {
        switch authResponse.sessionUpdateAction {
        case let .set(accessToken, refreshToken, identityToken):
            let authSession = InternalAuthSession(
                user: authResponse.user.toPrivyUser(),
                authToken: accessToken,
                refreshToken: refreshToken,
                identityToken: identityToken,
                loginMethod: loginMethod
            )
            try await setAuthSession(authSession)
            return authSession

        case .clear:
            await self.logout()
            throw PrivyError(.authenticationFailure(reason: .sessionExpired))

        case let .ignore(accessToken, refreshToken, identityToken):
            return try await self.handleIgnoreAuthSession(
                user: authResponse.user.toPrivyUser(),
                accessTokenFromResponse: accessToken,
                refreshTokenFromResponse: refreshToken,
                identityTokenFromResponse: identityToken,
                existingSessionTokens: existingSessionTokens,
                loginMethod: loginMethod
            )
        }
    }

    /// Handles session_update_action = "ignore" from POST /v1/sessions.
    ///
    /// The server returns "ignore" in four cases:
    /// 1. Access token is still valid (not expiring within 5 min) — tokens echoed back.
    /// 2. Refresh token reused within 15s (benign race) — nil tokens.
    /// 3. Concurrent rotation — fresh access token returned, refresh token is nil.
    /// 4. Rotation race lost — nil tokens.
    ///
    /// For each token, prefer the response value if present, fall back to existing session tokens.
    private func handleIgnoreAuthSession(
        user: InternalPrivyUser,
        accessTokenFromResponse: String?,
        refreshTokenFromResponse: String?,
        identityTokenFromResponse: String?,
        existingSessionTokens: AuthSessionTokens?,
        loginMethod: LoginMethod
    ) async throws -> InternalAuthSession {
        logger.debug("Session action 'ignore': freshAccessToken present: \(accessTokenFromResponse != nil), freshRefreshToken present: \(refreshTokenFromResponse != nil), freshIdentityToken present: \(identityTokenFromResponse != nil)")

        // Access or refresh token should never be null between these two options, but this satisfies
        // the compiler
        guard let accessToken = accessTokenFromResponse ?? existingSessionTokens?.authToken else {
            logger.error("Cannot restore session: no access token available from response or existing session.", error: nil)
            throw PrivyError(.authenticationFailure(reason: .sessionExpired))
        }

        // Refresh token priority: response → live state → persisted → pre-flight snapshot.
        // Live state is preferred over the pre-flight snapshot because a concurrent request
        // may have rotated the refresh token while this request was in-flight.
        let liveRefreshToken: String? = if case let .authenticated(session) = internalAuthStateManager.state {
            session.refreshToken
        } else {
            await authSessionTokensRepository.retrieveAuthTokens()?.refreshToken
        }

        guard let refreshToken = refreshTokenFromResponse ?? liveRefreshToken ?? existingSessionTokens?.refreshToken else {
            logger.error("Cannot restore session: no refresh token available from response or existing session.", error: nil)
            throw PrivyError(.authenticationFailure(reason: .sessionExpired))
        }

        let session = InternalAuthSession(
            user: user,
            authToken: accessToken,
            refreshToken: refreshToken,
            identityToken: identityTokenFromResponse ?? existingSessionTokens?.identityToken,
            loginMethod: loginMethod
        )
        try await authSessionTokensRepository.save(authTokens: session.toAuthSessionTokens())
        internalAuthStateManager.update(state: .authenticated(session))
        return session
    }
}
