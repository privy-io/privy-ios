import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Covers `AuthManagerImpl`'s login, session restore, refresh, and link/unlink/transfer paths.
internal final class AuthManagerImplTests: PrivyTestCase {
    private static let returnedUserId = "container-user"

    private var testAuthRepository: TestAuthRepository!
    private var testAuthRefreshService: TestAuthRefreshService!
    private var testStateManager: TestInternalAuthStateManager!
    private var testSessionTokensRepository: TestAuthSessionTokensRepository!
    private var testMfaTokenRepository: TestMfaTokenRepository!
    private var testBreadcrumbEmitter: TestBreadcrumbEmitter!
    private var testWalletMigrationManager: TestWalletMigrationManager!

    override internal func setUp() {
        super.setUp()
        let testAuthRepository = TestAuthRepository()
        let testAuthRefreshService = TestAuthRefreshService()
        let testStateManager = TestInternalAuthStateManager()
        let testSessionTokensRepository = TestAuthSessionTokensRepository()
        let testMfaTokenRepository = TestMfaTokenRepository()
        let testBreadcrumbEmitter = TestBreadcrumbEmitter()
        let testWalletMigrationManager = TestWalletMigrationManager()
        register(\PrivyContainer.authRepository) { testAuthRepository }
        register(\PrivyContainer.authRefreshService) { testAuthRefreshService }
        register(\PrivyContainer.internalAuthStateManager) { testStateManager }
        register(\PrivyContainer.authSessionRepository) { testSessionTokensRepository }
        register(\PrivyContainer.mfaTokenRepository) { testMfaTokenRepository }
        register(\PrivyContainer.breadcrumbEmitter) { testBreadcrumbEmitter }
        register(\PrivyContainer.walletMigrationManager) { testWalletMigrationManager }
        // The real `PrivyUser` resolves the whole wallet/iframe graph, which isn't usable off the main actor.
        register(\PrivyContainer.privyUser) { TestPrivyUser(id: Self.returnedUserId) }
        self.testAuthRepository = testAuthRepository
        self.testAuthRefreshService = testAuthRefreshService
        self.testStateManager = testStateManager
        self.testSessionTokensRepository = testSessionTokensRepository
        self.testMfaTokenRepository = testMfaTokenRepository
        self.testBreadcrumbEmitter = testBreadcrumbEmitter
        self.testWalletMigrationManager = testWalletMigrationManager
    }

    /// `AuthManagerImpl` kicks off `restoreSession()` from its initializer. With no stored tokens
    /// that settles the state to `.unauthenticated`, so wait for that first state update before a test
    /// starts changing state, otherwise it could land on top of the test's own setup.
    private func makeAuthManager() async -> AuthManager {
        let authManager: AuthManager = resolve(\PrivyContainer.authManager)
        for await _ in testStateManager.stateStream { break }
        return authManager
    }

    private func signIn(_ session: InternalAuthSession = .test()) {
        testStateManager.update(state: .authenticated(session))
    }

    /// `InternalAuthState` isn't `Equatable`, so tests compare a short label instead.
    private func label(_ state: InternalAuthState) -> String {
        switch state {
        case .notReady: "notReady"
        case .unauthenticated: "unauthenticated"
        case .authenticatedUnverified: "authenticatedUnverified"
        case .authenticated(let session): "authenticated(\(session.user.id))"
        }
    }

    private func authenticatedSession() throws -> InternalAuthSession {
        guard case .authenticated(let session) = testStateManager.state else {
            throw XCTSkip("Expected an authenticated state, got \(label(testStateManager.state))")
        }
        return session
    }

    private func assertRefreshServiceUnused(file: StaticString = #filePath, line: UInt = #line) async {
        let requests = await testAuthRefreshService.refreshAuthRequests
        XCTAssertTrue(requests.isEmpty, "Expected no Privy refresh requests", file: file, line: line)
    }

    private func assertAuthenticationFailure(
        _ error: Error,
        matches expected: (PrivyErrorCode.AuthenticationFailureReason) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .authenticationFailure(let reason) = (error as? PrivyError)?.errorCode, expected(reason) else {
            return XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    // MARK: Initialization

    internal func testInitializationWithNoStoredTokensSettlesToUnauthenticated() async {
        _ = await makeAuthManager()

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        await assertRefreshServiceUnused()
    }

    // MARK: login

    internal func testLoginSavesTokensAndAuthenticates() async throws {
        let authManager = await makeAuthManager()
        testAuthRepository.authenticateResult = .success(.test(userId: "logged-in-user"))

        let user = try await authManager.login(with: .email("user@privy.io", code: "123456"))

        XCTAssertEqual(user.id, Self.returnedUserId)
        XCTAssertEqual(label(testStateManager.state), "authenticated(logged-in-user)")
        let saved = try XCTUnwrap(testSessionTokensRepository.saveRequests.last)
        XCTAssertEqual(saved.authToken, "new-auth-token")
        XCTAssertEqual(saved.refreshToken, "new-refresh-token")
        XCTAssertEqual(String(describing: saved.loginMethod), String(describing: LoginMethod.email))
    }

    internal func testLoginRecordsLoginMethodOfTheLoginType() async throws {
        let authManager = await makeAuthManager()
        testAuthRepository.authenticateResult = .success(.test())

        _ = try await authManager.login(with: .phone("+15555550100", code: "123456"))

        let session = try authenticatedSession()
        XCTAssertEqual(String(describing: session.loginMethod), String(describing: LoginMethod.phone))
    }

    internal func testLoginRunsAutomaticWalletMigration() async throws {
        let authManager = await makeAuthManager()
        testAuthRepository.authenticateResult = .success(.test())

        _ = try await authManager.login(with: .email("user@privy.io", code: "123456"))

        XCTAssertEqual(testWalletMigrationManager.migrateWalletsIfNeededCallCount, 1)
    }

    internal func testLoginSkipsWalletMigrationWhenDisabled() async throws {
        let config = PrivyConfig(
            appId: "test-app-id",
            appClientId: "test-client-id",
            embeddedWalletConfig: PrivyEmbeddedWalletConfig(disableAutomaticMigration: true)
        )
        register(\PrivyContainer.config) { config }
        let authManager = await makeAuthManager()
        testAuthRepository.authenticateResult = .success(.test())

        _ = try await authManager.login(with: .email("user@privy.io", code: "123456"))

        XCTAssertEqual(testWalletMigrationManager.migrateWalletsIfNeededCallCount, 0)
    }

    internal func testLoginSucceedsEvenIfWalletMigrationFails() async throws {
        let authManager = await makeAuthManager()
        testAuthRepository.authenticateResult = .success(.test(userId: "logged-in-user"))
        testWalletMigrationManager.migrateWalletsIfNeededResult = .failure(URLError(.badServerResponse))

        let user = try await authManager.login(with: .email("user@privy.io", code: "123456"))

        XCTAssertEqual(user.id, Self.returnedUserId)
        XCTAssertEqual(label(testStateManager.state), "authenticated(logged-in-user)")
    }

    internal func testLoginFailureUnauthenticatesAndRethrows() async {
        let authManager = await makeAuthManager()
        signIn()
        testAuthRepository.authenticateResult = .failure(URLError(.badServerResponse))

        await XCTAssertThrowsErrorAsync(try await authManager.login(with: .email("user@privy.io", code: "bad"))) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        XCTAssertTrue(testSessionTokensRepository.saveRequests.isEmpty)
    }

    internal func testLoginAccountTransferErrorPreservesExistingSession() async {
        let authManager = await makeAuthManager()
        signIn(.test(userId: "existing-user"))
        testAuthRepository.authenticateResult = .failure(
            AccountTransferBackendError(
                nonce: "transfer-nonce",
                embeddedWalletAddress: nil,
                farcasterEmbeddedAddress: nil,
                displayName: nil,
                oAuthUserInfo: nil
            )
        )

        await XCTAssertThrowsErrorAsync(try await authManager.login(with: .email("user@privy.io", code: "123456"))) { error in
            assertAuthenticationFailure(error) { if case .accountTransferRequired = $0 { true } else { false } }
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    internal func testLoginWithClearActionLogsOutAndThrowsSessionExpired() async {
        let authManager = await makeAuthManager()
        testAuthRepository.authenticateResult = .success(.test(sessionUpdateAction: .clear))

        await XCTAssertThrowsErrorAsync(try await authManager.login(with: .email("user@privy.io", code: "123456"))) { error in
            assertAuthenticationFailure(error) { if case .sessionExpired = $0 { true } else { false } }
        }

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        XCTAssertEqual(testSessionTokensRepository.deleteCallCount, 1)
    }

    // MARK: restoreSession

    internal func testRestoreSessionWithoutStoredTokensUnauthenticatesWithoutRefreshing() async {
        let authManager = await makeAuthManager()
        signIn()

        await authManager.restoreSession()

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        await assertRefreshServiceUnused()
        XCTAssertTrue(testBreadcrumbEmitter.emitted.isEmpty)
    }

    internal func testRestoreSessionRefreshesStoredTokensAndAuthenticates() async throws {
        let authManager = await makeAuthManager()
        testSessionTokensRepository.storedTokens = .test(authToken: "stored-auth", refreshToken: "stored-refresh")
        await testAuthRefreshService.stub(.success(.test(userId: "restored-user")))

        await authManager.restoreSession()

        let requests = await testAuthRefreshService.refreshAuthRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.authToken, "stored-auth")
        XCTAssertEqual(requests.first?.refreshToken, "stored-refresh")
        XCTAssertEqual(label(testStateManager.state), "authenticated(restored-user)")
        XCTAssertEqual(
            testBreadcrumbEmitter.emitted.map(\.event),
            ["auth.session_restore.started", "auth.session_restore.completed"]
        )
        // The refreshed tokens replace the stored ones.
        XCTAssertEqual(testSessionTokensRepository.storedTokens?.authToken, "new-auth-token")
    }

    internal func testRestoreSessionFailureLogsOutAndEmitsFailedBreadcrumb() async {
        let authManager = await makeAuthManager()
        testSessionTokensRepository.storedTokens = .test()
        await testAuthRefreshService.stub(.failure(URLError(.badServerResponse)))
        signIn()

        await authManager.restoreSession()

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        XCTAssertNil(testSessionTokensRepository.storedTokens)
        XCTAssertEqual(
            testBreadcrumbEmitter.emitted.map(\.event),
            ["auth.session_restore.started", "auth.session_restore.failed"]
        )
    }

    internal func testRestoreSessionConnectivityFailureKeepsTokensAndMarksUnverified() async {
        let authManager = await makeAuthManager()
        testSessionTokensRepository.storedTokens = .test()
        await testAuthRefreshService.stub(.failure(URLError(.notConnectedToInternet)))

        await authManager.restoreSession()

        XCTAssertEqual(label(testStateManager.state), "authenticatedUnverified")
        XCTAssertNotNil(testSessionTokensRepository.storedTokens)
        XCTAssertEqual(testSessionTokensRepository.deleteCallCount, 0)
        XCTAssertEqual(
            testBreadcrumbEmitter.emitted.map(\.event),
            ["auth.session_restore.started", "auth.session_restore.failed"]
        )
    }

    // MARK: refreshSession

    internal func testRefreshSessionThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(try await authManager.refreshSession()) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }

        await assertRefreshServiceUnused()
    }

    internal func testRefreshSessionSavesRotatedTokens() async throws {
        let authManager = await makeAuthManager()
        signIn(.test(userId: "user-1"))
        await testAuthRefreshService.stub(.success(.test(userId: "user-1")))

        let session = try await authManager.refreshSession()

        XCTAssertEqual(session.authToken, "new-auth-token")
        XCTAssertEqual(session.refreshToken, "new-refresh-token")
        XCTAssertEqual(testSessionTokensRepository.saveRequests.last?.authToken, "new-auth-token")
        XCTAssertEqual(try authenticatedSession().authToken, "new-auth-token")
        let requests = await testAuthRefreshService.refreshAuthRequests
        XCTAssertEqual(requests.first?.authToken, "test-auth-token")
        XCTAssertEqual(requests.first?.refreshToken, "test-refresh-token")
    }

    internal func testRefreshSessionWithClearActionLogsOutAndThrowsSessionExpired() async {
        let authManager = await makeAuthManager()
        signIn()
        await testAuthRefreshService.stub(.success(.test(sessionUpdateAction: .clear)))

        await XCTAssertThrowsErrorAsync(try await authManager.refreshSession()) { error in
            assertAuthenticationFailure(error) { if case .sessionExpired = $0 { true } else { false } }
        }

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        XCTAssertEqual(testSessionTokensRepository.deleteCallCount, 1)
    }

    internal func testRefreshSessionFailureLogsOutAndRethrows() async {
        let authManager = await makeAuthManager()
        signIn()
        await testAuthRefreshService.stub(.failure(URLError(.badServerResponse)))

        await XCTAssertThrowsErrorAsync(try await authManager.refreshSession()) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        XCTAssertEqual(testSessionTokensRepository.deleteCallCount, 1)
        XCTAssertEqual(testAuthRepository.logoutSessionRequests, ["test-auth-token"])
    }

    internal func testRefreshSessionConnectivityFailureKeepsSessionData() async {
        let authManager = await makeAuthManager()
        signIn()
        await testAuthRefreshService.stub(.failure(URLError(.timedOut)))

        await XCTAssertThrowsErrorAsync(try await authManager.refreshSession()) { error in
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticatedUnverified")
        XCTAssertEqual(testSessionTokensRepository.deleteCallCount, 0)
        XCTAssertTrue(testAuthRepository.logoutSessionRequests.isEmpty)
    }

    // MARK: refreshSession — session_update_action = ignore

    internal func testRefreshSessionIgnoreFallsBackToExistingTokens() async throws {
        let authManager = await makeAuthManager()
        signIn()
        await testAuthRefreshService.stub(.success(.test(sessionUpdateAction: .ignore(accessToken: nil, refreshToken: nil, identityToken: nil))))

        let session = try await authManager.refreshSession()

        XCTAssertEqual(session.authToken, "test-auth-token")
        XCTAssertEqual(session.refreshToken, "test-refresh-token")
        XCTAssertEqual(label(testStateManager.state), "authenticated(test-user-id)")
    }

    internal func testRefreshSessionIgnorePrefersTokensFromTheResponse() async throws {
        let authManager = await makeAuthManager()
        signIn()
        await testAuthRefreshService.stub(
            .success(.test(sessionUpdateAction: .ignore(accessToken: "echoed-auth", refreshToken: "echoed-refresh", identityToken: "echoed-identity")))
        )

        let session = try await authManager.refreshSession()

        XCTAssertEqual(session.authToken, "echoed-auth")
        XCTAssertEqual(session.refreshToken, "echoed-refresh")
        XCTAssertEqual(session.identityToken, "echoed-identity")
        XCTAssertEqual(testSessionTokensRepository.saveRequests.last?.refreshToken, "echoed-refresh")
    }

    internal func testRefreshSessionIgnorePrefersRefreshTokenRotatedWhileInFlight() async throws {
        let authManager = await makeAuthManager()
        signIn()
        // A concurrent request rotates the refresh token while this refresh is still in flight.
        let rotated = InternalAuthSession(
            user: InternalAuthSession.test().user,
            authToken: "test-auth-token",
            refreshToken: "rotated-refresh",
            identityToken: nil,
            loginMethod: .email
        )
        await testAuthRefreshService.stub(.success(.test(sessionUpdateAction: .ignore(accessToken: nil, refreshToken: nil, identityToken: nil))))
        await testAuthRefreshService.onRefresh { [testStateManager] in
            testStateManager?.update(state: .authenticated(rotated))
        }

        let session = try await authManager.refreshSession()

        XCTAssertEqual(session.refreshToken, "rotated-refresh")
    }

    // MARK: refreshSession — custom auth

    internal func testRefreshSessionForCustomAuthReauthenticatesWithProviderToken() async throws {
        let config = PrivyConfig(
            appId: "test-app-id",
            appClientId: "test-client-id",
            customAuthConfig: PrivyLoginWithCustomAuthConfig(tokenProvider: { "fresh-custom-token" })
        )
        register(\PrivyContainer.config) { config }
        let authManager = await makeAuthManager()
        signIn(.test(userId: "custom-user", loginMethod: .customAccessToken))
        testAuthRepository.authenticateResult = .success(.test(userId: "custom-user"))

        let session = try await authManager.refreshSession()

        XCTAssertEqual(session.authToken, "new-auth-token")
        guard case .customAccessToken(let token) = testAuthRepository.authenticateRequests.first else {
            return XCTFail("Expected a .customAccessToken authenticate request")
        }
        XCTAssertEqual(token, "fresh-custom-token")
        await assertRefreshServiceUnused()
    }

    internal func testRefreshSessionForCustomAuthWithoutProviderLogsOut() async {
        let authManager = await makeAuthManager()
        signIn(.test(loginMethod: .customAccessToken))

        await XCTAssertThrowsErrorAsync(try await authManager.refreshSession()) { error in
            assertAuthenticationFailure(error) { if case .noCustomAuthProviderConfigured = $0 { true } else { false } }
        }

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
    }

    internal func testRefreshSessionForCustomAuthWithNoTokenLogsOut() async {
        let config = PrivyConfig(
            appId: "test-app-id",
            appClientId: "test-client-id",
            customAuthConfig: PrivyLoginWithCustomAuthConfig(tokenProvider: { nil })
        )
        register(\PrivyContainer.config) { config }
        let authManager = await makeAuthManager()
        signIn(.test(loginMethod: .customAccessToken))

        await XCTAssertThrowsErrorAsync(try await authManager.refreshSession()) { error in
            assertAuthenticationFailure(error) { if case .customAuthProviderReturnedNoToken = $0 { true } else { false } }
        }

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
    }

    // MARK: refreshSessionIfNeeded

    internal func testRefreshSessionIfNeededThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(try await authManager.refreshSessionIfNeeded()) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }
    }

    internal func testRefreshSessionIfNeededThrowsForMalformedAuthToken() async {
        let authManager = await makeAuthManager()
        signIn(.test(authToken: "not-a-jwt"))

        await XCTAssertThrowsErrorAsync(try await authManager.refreshSessionIfNeeded()) { error in
            assertAuthenticationFailure(error) { if case .invalidJwt = $0 { true } else { false } }
        }

        await assertRefreshServiceUnused()
    }

    internal func testRefreshSessionIfNeededReturnsCurrentSessionWhenTokenIsFresh() async throws {
        let authManager = await makeAuthManager()
        let freshToken = String.testJwt(expiresIn: 3_600)
        signIn(.test(authToken: freshToken))

        let session = try await authManager.refreshSessionIfNeeded()

        XCTAssertEqual(session.authToken, freshToken)
        await assertRefreshServiceUnused()
    }

    internal func testRefreshSessionIfNeededRefreshesWhenTokenIsExpired() async throws {
        let authManager = await makeAuthManager()
        signIn(.test(authToken: .testJwt(expiresIn: -10)))
        await testAuthRefreshService.stub(.success(.test()))

        let session = try await authManager.refreshSessionIfNeeded()

        XCTAssertEqual(session.authToken, "new-auth-token")
    }

    internal func testRefreshSessionIfNeededRefreshesWithinTheExpirationThreshold() async throws {
        let authManager = await makeAuthManager()
        // Still technically valid, but inside the 60s eager-refresh window.
        signIn(.test(authToken: .testJwt(expiresIn: 30)))
        await testAuthRefreshService.stub(.success(.test()))

        let session = try await authManager.refreshSessionIfNeeded()

        XCTAssertEqual(session.authToken, "new-auth-token")
    }

    // MARK: refreshUser

    internal func testRefreshUserThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(try await authManager.refreshUser()) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }
    }

    internal func testRefreshUserThrowsForMalformedAuthToken() async {
        let authManager = await makeAuthManager()
        signIn(.test(authToken: "not-a-jwt"))

        await XCTAssertThrowsErrorAsync(try await authManager.refreshUser()) { error in
            assertAuthenticationFailure(error) { if case .invalidJwt = $0 { true } else { false } }
        }

        XCTAssertTrue(testAuthRepository.refreshUserRequests.isEmpty)
    }

    internal func testRefreshUserFetchesUserAndUpdatesStateWhenTokenIsFresh() async throws {
        let authManager = await makeAuthManager()
        let freshToken = String.testJwt(expiresIn: 3_600)
        signIn(.test(userId: "old-user", authToken: freshToken))
        testAuthRepository.refreshUserResult = .success(.test(userId: "new-user", identityToken: "new-identity"))

        let user = try await authManager.refreshUser()

        XCTAssertEqual(user.id, "new-user")
        XCTAssertEqual(testAuthRepository.refreshUserRequests, [freshToken])
        let session = try authenticatedSession()
        XCTAssertEqual(session.user.id, "new-user")
        XCTAssertEqual(session.identityToken, "new-identity")
        XCTAssertEqual(session.authToken, freshToken)
        await assertRefreshServiceUnused()
    }

    internal func testRefreshUserRefreshesSessionWhenTokenIsExpired() async throws {
        let authManager = await makeAuthManager()
        signIn(.test(authToken: .testJwt(expiresIn: -10)))
        await testAuthRefreshService.stub(.success(.test(userId: "refreshed-user")))

        let user = try await authManager.refreshUser()

        XCTAssertEqual(user.id, "refreshed-user")
        XCTAssertTrue(testAuthRepository.refreshUserRequests.isEmpty)
    }

    internal func testRefreshUserPropagatesRepositoryFailureWithoutChangingState() async {
        let authManager = await makeAuthManager()
        signIn(.test(userId: "old-user", authToken: .testJwt(expiresIn: 3_600)))
        testAuthRepository.refreshUserResult = .failure(URLError(.badServerResponse))

        await XCTAssertThrowsErrorAsync(try await authManager.refreshUser()) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(old-user)")
    }

    // MARK: logout

    internal func testLogoutClearsStorageAndNotifiesBackend() async {
        let authManager = await makeAuthManager()
        signIn()
        testSessionTokensRepository.storedTokens = .test()
        testMfaTokenRepository.storedToken = "mfa-token"

        await authManager.logout()

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        XCTAssertNil(testSessionTokensRepository.storedTokens)
        XCTAssertNil(testMfaTokenRepository.storedToken)
        XCTAssertEqual(testAuthRepository.logoutSessionRequests, ["test-auth-token"])
    }

    internal func testLogoutWhenUnauthenticatedSkipsBackendCall() async {
        let authManager = await makeAuthManager()

        await authManager.logout()

        XCTAssertTrue(testAuthRepository.logoutSessionRequests.isEmpty)
    }

    internal func testLogoutStillCompletesWhenBackendCallFails() async {
        let authManager = await makeAuthManager()
        signIn()
        testAuthRepository.logoutSessionResult = .failure(URLError(.badServerResponse))

        await authManager.logout()

        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
        XCTAssertEqual(testAuthRepository.logoutSessionRequests.count, 1)
    }

    // MARK: link / unlink / transfer

    private static let linkedUserId = "linked-user"

    private func accountTransferError() -> AccountTransferBackendError {
        AccountTransferBackendError(
            nonce: "transfer-nonce",
            embeddedWalletAddress: nil,
            farcasterEmbeddedAddress: nil,
            displayName: nil,
            oAuthUserInfo: nil
        )
    }

    /// Signs in and stubs the Privy refresh that every link/unlink call performs first, which rotates the
    /// auth token to `new-auth-token`.
    private func signInForLinkFlow() async {
        signIn(.test(userId: "existing-user"))
        await testAuthRefreshService.stub(.success(.test(userId: "existing-user")))
    }

    private func assertAccountTransferRequired(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        assertAuthenticationFailure(error, matches: {
            if case .accountTransferRequired(let nonce, _) = $0 { nonce == "transfer-nonce" } else { false }
        }, file: file, line: line)
    }

    private func assertSessionReplacedUser(
        _ user: PrivyUser,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(user.id, Self.returnedUserId, file: file, line: line)
        let session = try authenticatedSession()
        XCTAssertEqual(session.user.id, Self.linkedUserId, file: file, line: line)
        XCTAssertEqual(session.authToken, "new-auth-token", file: file, line: line)
        XCTAssertEqual(testSessionTokensRepository.saveRequests.last?.authToken, "new-auth-token", file: file, line: line)
    }

    // linkAccount

    internal func testLinkAccountSendsRefreshedTokenAndReplacesUser() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.linkResult = .success(.test(userId: Self.linkedUserId))

        let user = try await authManager.linkAccount(with: .email("user@privy.io", code: "123456"))

        try assertSessionReplacedUser(user)
        XCTAssertEqual(testAuthRepository.linkRequests.count, 1)
        XCTAssertEqual(testAuthRepository.linkRequests.first?.authToken, "new-auth-token")
        guard case .email(let email, let code) = testAuthRepository.linkRequests.first?.loginType else {
            return XCTFail("Expected an .email link request")
        }
        XCTAssertEqual(email, "user@privy.io")
        XCTAssertEqual(code, "123456")
    }

    internal func testLinkAccountThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(try await authManager.linkAccount(with: .email("user@privy.io", code: "123456"))) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }

        XCTAssertTrue(testAuthRepository.linkRequests.isEmpty)
        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
    }

    internal func testLinkAccountInvalidatesSessionWhenRefreshFails() async {
        let authManager = await makeAuthManager()
        signIn()
        await testAuthRefreshService.stub(.failure(URLError(.badServerResponse)))

        await XCTAssertThrowsErrorAsync(try await authManager.linkAccount(with: .email("user@privy.io", code: "123456"))) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertTrue(testAuthRepository.linkRequests.isEmpty)
        XCTAssertEqual(label(testStateManager.state), "unauthenticated")
    }

    internal func testLinkAccountMapsAccountTransferErrorAndKeepsSession() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.linkResult = .failure(accountTransferError())

        await XCTAssertThrowsErrorAsync(try await authManager.linkAccount(with: .email("user@privy.io", code: "123456"))) { error in
            assertAccountTransferRequired(error)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    internal func testLinkAccountPropagatesOtherErrorsWithoutLoggingOut() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.linkResult = .failure(URLError(.badServerResponse))

        await XCTAssertThrowsErrorAsync(try await authManager.linkAccount(with: .email("user@privy.io", code: "123456"))) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    // transferAccount

    internal func testTransferAccountSendsRefreshedTokenAndReplacesUser() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.transferResult = .success(.test(userId: Self.linkedUserId))

        let user = try await authManager.transferAccount(with: .email(address: "user@privy.io", code: "123456", nonce: "transfer-nonce"))

        try assertSessionReplacedUser(user)
        XCTAssertEqual(testAuthRepository.transferRequests.count, 1)
        XCTAssertEqual(testAuthRepository.transferRequests.first?.authToken, "new-auth-token")
        guard case .email(let address, _, let nonce) = testAuthRepository.transferRequests.first?.transferType else {
            return XCTFail("Expected an .email transfer request")
        }
        XCTAssertEqual(address, "user@privy.io")
        XCTAssertEqual(nonce, "transfer-nonce")
    }

    internal func testTransferAccountThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(
            try await authManager.transferAccount(with: .email(address: "user@privy.io", code: "123456", nonce: "transfer-nonce"))
        ) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }

        XCTAssertTrue(testAuthRepository.transferRequests.isEmpty)
    }

    internal func testTransferAccountMapsAccountTransferErrorAndKeepsSession() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.transferResult = .failure(accountTransferError())

        await XCTAssertThrowsErrorAsync(
            try await authManager.transferAccount(with: .email(address: "user@privy.io", code: "123456", nonce: "transfer-nonce"))
        ) { error in
            assertAccountTransferRequired(error)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    internal func testTransferAccountPropagatesOtherErrors() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.transferResult = .failure(URLError(.timedOut))

        await XCTAssertThrowsErrorAsync(
            try await authManager.transferAccount(with: .phone(phoneNumber: "+15555550100", code: "123456", nonce: "transfer-nonce"))
        ) { error in
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    // unlinkAccount

    internal func testUnlinkAccountSendsRefreshedTokenAndReplacesUser() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.unlinkResult = .success(.test(userId: Self.linkedUserId))

        let user = try await authManager.unlinkAccount(with: .email(address: "user@privy.io"))

        try assertSessionReplacedUser(user)
        XCTAssertEqual(testAuthRepository.unlinkRequests.count, 1)
        XCTAssertEqual(testAuthRepository.unlinkRequests.first?.authToken, "new-auth-token")
        guard case .email(let address) = testAuthRepository.unlinkRequests.first?.unlinkType else {
            return XCTFail("Expected an .email unlink request")
        }
        XCTAssertEqual(address, "user@privy.io")
    }

    internal func testUnlinkAccountThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(try await authManager.unlinkAccount(with: .email(address: "user@privy.io"))) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }

        XCTAssertTrue(testAuthRepository.unlinkRequests.isEmpty)
    }

    internal func testUnlinkAccountPropagatesRepositoryFailureWithoutLoggingOut() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.unlinkResult = .failure(URLError(.badServerResponse))

        await XCTAssertThrowsErrorAsync(try await authManager.unlinkAccount(with: .phone(phoneNumber: "+15555550100"))) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    // linkPasskey / unlinkPasskey

    internal func testLinkPasskeySendsCredentialAndReplacesUser() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.linkPasskeyResult = .success(.test(userId: Self.linkedUserId))

        let user = try await authManager.linkPasskey(credential: .test(id: "new-passkey"), relyingParty: "example.com")

        try assertSessionReplacedUser(user)
        let request = try XCTUnwrap(testAuthRepository.linkPasskeyRequests.first)
        XCTAssertEqual(request.credential.id, "new-passkey")
        XCTAssertEqual(request.relyingParty, "example.com")
        XCTAssertEqual(request.authToken, "new-auth-token")
    }

    internal func testLinkPasskeyThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(try await authManager.linkPasskey(credential: .test(), relyingParty: "example.com")) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }

        XCTAssertTrue(testAuthRepository.linkPasskeyRequests.isEmpty)
    }

    internal func testLinkPasskeyPropagatesRepositoryFailure() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.linkPasskeyResult = .failure(URLError(.badServerResponse))

        await XCTAssertThrowsErrorAsync(try await authManager.linkPasskey(credential: .test(), relyingParty: "example.com")) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    internal func testUnlinkPasskeyRemovingAsMfaClearsStoredMfaToken() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testMfaTokenRepository.storedToken = "mfa-token"
        testAuthRepository.unlinkPasskeyResult = .success(.test(userId: Self.linkedUserId))

        let user = try await authManager.unlinkPasskey(credentialId: "passkey-1", removeAsMfa: true)

        try assertSessionReplacedUser(user)
        let request = try XCTUnwrap(testAuthRepository.unlinkPasskeyRequests.first)
        XCTAssertEqual(request.credentialId, "passkey-1")
        XCTAssertTrue(request.removeAsMfa)
        XCTAssertEqual(request.authToken, "new-auth-token")
        XCTAssertEqual(request.mfaToken, "mfa-token")
        XCTAssertEqual(testMfaTokenRepository.deleteCallCount, 1)
        XCTAssertNil(testMfaTokenRepository.storedToken)
    }

    internal func testUnlinkPasskeyKeepsMfaTokenWhenNotRemovingAsMfa() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testMfaTokenRepository.storedToken = "mfa-token"
        testAuthRepository.unlinkPasskeyResult = .success(.test(userId: Self.linkedUserId))

        _ = try await authManager.unlinkPasskey(credentialId: "passkey-1", removeAsMfa: false)

        let request = try XCTUnwrap(testAuthRepository.unlinkPasskeyRequests.first)
        XCTAssertFalse(request.removeAsMfa)
        XCTAssertEqual(request.mfaToken, "mfa-token")
        XCTAssertEqual(testMfaTokenRepository.deleteCallCount, 0)
        XCTAssertEqual(testMfaTokenRepository.storedToken, "mfa-token")
    }

    internal func testUnlinkPasskeyFailureKeepsMfaToken() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testMfaTokenRepository.storedToken = "mfa-token"
        testAuthRepository.unlinkPasskeyResult = .failure(URLError(.badServerResponse))

        await XCTAssertThrowsErrorAsync(try await authManager.unlinkPasskey(credentialId: "passkey-1", removeAsMfa: true)) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(testMfaTokenRepository.deleteCallCount, 0)
        XCTAssertEqual(testMfaTokenRepository.storedToken, "mfa-token")
    }

    internal func testUnlinkPasskeyThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(try await authManager.unlinkPasskey(credentialId: "passkey-1", removeAsMfa: true)) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }

        XCTAssertTrue(testAuthRepository.unlinkPasskeyRequests.isEmpty)
    }

    // linkWithSiws / unlinkSiwsWallet

    internal func testLinkWithSiwsBuildsRequestFromMetadataAndReplacesUser() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.siwsLinkResult = .success(.test(userId: Self.linkedUserId))

        let user = try await authManager.linkWithSiws(
            address: "SoLaNaAddress",
            signing: "siws-message",
            with: "siws-signature",
            metadata: WalletLoginMetadata(walletClientType: .metamask, connectorType: "wallet_connect")
        )

        try assertSessionReplacedUser(user)
        let request = try XCTUnwrap(testAuthRepository.siwsLinkRequests.first)
        XCTAssertEqual(request.authToken, "new-auth-token")
        XCTAssertEqual(request.body.address, "SoLaNaAddress")
        XCTAssertEqual(request.body.message, "siws-message")
        XCTAssertEqual(request.body.signature, "siws-signature")
        XCTAssertEqual(request.body.walletClientType, WalletClientType.metamask.rawValue)
        XCTAssertEqual(request.body.connectorType, "wallet_connect")
        XCTAssertEqual(request.body.messageType, .plain)
    }

    internal func testLinkWithSiwsWithoutMetadataOmitsWalletFields() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.siwsLinkResult = .success(.test(userId: Self.linkedUserId))

        _ = try await authManager.linkWithSiws(address: nil, signing: "siws-message", with: "siws-signature", metadata: nil)

        let request = try XCTUnwrap(testAuthRepository.siwsLinkRequests.first)
        XCTAssertNil(request.body.address)
        XCTAssertNil(request.body.walletClientType)
        XCTAssertNil(request.body.connectorType)
    }

    internal func testLinkWithSiwsThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(
            try await authManager.linkWithSiws(address: nil, signing: "siws-message", with: "siws-signature", metadata: nil)
        ) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }

        XCTAssertTrue(testAuthRepository.siwsLinkRequests.isEmpty)
    }

    internal func testLinkWithSiwsMapsAccountTransferErrorAndKeepsSession() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.siwsLinkResult = .failure(accountTransferError())

        await XCTAssertThrowsErrorAsync(
            try await authManager.linkWithSiws(address: nil, signing: "siws-message", with: "siws-signature", metadata: nil)
        ) { error in
            assertAccountTransferRequired(error)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    internal func testLinkWithSiwsPropagatesOtherErrors() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.siwsLinkResult = .failure(URLError(.badServerResponse))

        await XCTAssertThrowsErrorAsync(
            try await authManager.linkWithSiws(address: nil, signing: "siws-message", with: "siws-signature", metadata: nil)
        ) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }

    internal func testUnlinkSiwsWalletSendsAddressAndReplacesUser() async throws {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.siwsUnlinkResult = .success(.test(userId: Self.linkedUserId))

        let user = try await authManager.unlinkSiwsWallet(address: "SoLaNaAddress")

        try assertSessionReplacedUser(user)
        let request = try XCTUnwrap(testAuthRepository.siwsUnlinkRequests.first)
        XCTAssertEqual(request.body.address, "SoLaNaAddress")
        XCTAssertEqual(request.authToken, "new-auth-token")
    }

    internal func testUnlinkSiwsWalletThrowsWhenNotLoggedIn() async {
        let authManager = await makeAuthManager()

        await XCTAssertThrowsErrorAsync(try await authManager.unlinkSiwsWallet(address: "SoLaNaAddress")) { error in
            assertAuthenticationFailure(error) { if case .notLoggedIn = $0 { true } else { false } }
        }

        XCTAssertTrue(testAuthRepository.siwsUnlinkRequests.isEmpty)
    }

    internal func testUnlinkSiwsWalletPropagatesRepositoryFailure() async {
        let authManager = await makeAuthManager()
        await signInForLinkFlow()
        testAuthRepository.siwsUnlinkResult = .failure(URLError(.badServerResponse))

        await XCTAssertThrowsErrorAsync(try await authManager.unlinkSiwsWallet(address: "SoLaNaAddress")) { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        XCTAssertEqual(label(testStateManager.state), "authenticated(existing-user)")
    }
}
