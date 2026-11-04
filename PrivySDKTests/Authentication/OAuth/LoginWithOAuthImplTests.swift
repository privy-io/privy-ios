import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// The browser / native Apple legs of the flow (`ASWebAuthenticationSession`,
/// `ASAuthorizationController`) can't run in a unit test, so these cover everything up to that point
/// (URL scheme resolution, PKCE + `/init` request construction, init URL validation, auth guards)
/// plus `unlink`, which never touches UI. Each flow is stopped at the web-session boundary by
/// handing back an unparseable init URL.
internal final class LoginWithOAuthImplTests: PrivyTestCase {
    private struct StubError: Error {}

    private var testAuthManager: TestAuthManager!
    private var loginWithOAuth: LoginWithOAuth!

    override internal func setUp() {
        super.setUp()
        let testAuthManager = TestAuthManager()
        testAuthManager.ensureAuthenticatedResult = .success(.test())
        testAuthManager.generateOAuthUrlResult = .success(.test(url: ""))
        register(\PrivyContainer.authManager) { testAuthManager }
        register(\PrivyContainer.pkceHelper) { TestPKCEHelper() }
        self.testAuthManager = testAuthManager
        self.loginWithOAuth = resolve(\PrivyContainer.loginWithOAuth)
    }

    private func assertInvalidProviderUrl(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        guard case .authenticationError(let message) = error as? LoginWithOAuthError else {
            return XCTFail("Expected LoginWithOAuthError.authenticationError, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(message, "Invalid oAuth provider URL", file: file, line: line)
    }

    // MARK: login

    internal func testLoginSendsPkceInitRequestWithoutAuthToken() async {
        await XCTAssertThrowsErrorAsync(try await loginWithOAuth.login(with: .google, appUrlScheme: "myapp")) { error in
            assertInvalidProviderUrl(error)
        }

        let request = testAuthManager.generateOAuthUrlRequests.first
        XCTAssertEqual(testAuthManager.generateOAuthUrlRequests.count, 1)
        XCTAssertEqual(request?.provider, .google)
        XCTAssertEqual(request?.redirectUri, "myapp://")
        XCTAssertEqual(request?.codeChallenge, "challenge-for-\(TestPKCEHelper.codeVerifier)")
        XCTAssertEqual(request?.stateCode, TestPKCEHelper.stateCode)
        XCTAssertNil(request?.authToken)
        XCTAssertTrue(testAuthManager.loginRequests.isEmpty)
    }

    internal func testLoginDoesNotDoubleAppendSchemeSeparator() async {
        await XCTAssertThrowsErrorAsync(try await loginWithOAuth.login(with: .discord, appUrlScheme: "myapp://")) { _ in }

        XCTAssertEqual(testAuthManager.generateOAuthUrlRequests.first?.redirectUri, "myapp://")
    }

    internal func testLoginPropagatesInitFailure() async {
        testAuthManager.generateOAuthUrlResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithOAuth.login(with: .google, appUrlScheme: "myapp")) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.loginRequests.isEmpty)
    }

    // MARK: link

    internal func testLinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithOAuth.link(with: .google, appUrlScheme: "myapp")) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.generateOAuthUrlRequests.isEmpty)
        XCTAssertTrue(testAuthManager.linkAccountRequests.isEmpty)
    }

    internal func testLinkSendsAuthTokenWithInitRequest() async {
        await XCTAssertThrowsErrorAsync(try await loginWithOAuth.link(with: .twitter, appUrlScheme: "myapp")) { error in
            assertInvalidProviderUrl(error)
        }

        let request = testAuthManager.generateOAuthUrlRequests.first
        XCTAssertEqual(request?.provider, .twitter)
        XCTAssertEqual(request?.authToken, "test-auth-token")
        XCTAssertTrue(testAuthManager.linkAccountRequests.isEmpty)
    }

    // MARK: transferAccount

    internal func testTransferAccountRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(
            try await loginWithOAuth.transferAccount(nonce: "n", with: .google, appUrlScheme: "myapp")
        ) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.generateOAuthUrlRequests.isEmpty)
        XCTAssertTrue(testAuthManager.transferAccountRequests.isEmpty)
    }

    internal func testTransferAccountSendsAuthTokenWithInitRequest() async {
        await XCTAssertThrowsErrorAsync(
            try await loginWithOAuth.transferAccount(nonce: "n", with: .discord, appUrlScheme: "myapp")
        ) { error in
            assertInvalidProviderUrl(error)
        }

        let request = testAuthManager.generateOAuthUrlRequests.first
        XCTAssertEqual(request?.provider, .discord)
        XCTAssertEqual(request?.authToken, "test-auth-token")
        XCTAssertTrue(testAuthManager.transferAccountRequests.isEmpty)
    }

    // MARK: unlink

    internal func testUnlinkSucceeds() async throws {
        testAuthManager.unlinkAccountResult = .success(TestPrivyUser(id: "unlinked-user"))

        let user = try await loginWithOAuth.unlink(with: .google, subject: "google-subject")

        XCTAssertEqual(user.id, "unlinked-user")
        guard case .oauth(let provider, let subject) = testAuthManager.unlinkAccountRequests.first else {
            return XCTFail("Expected an .oauth unlink request")
        }
        XCTAssertEqual(provider, .google)
        XCTAssertEqual(subject, "google-subject")
    }

    internal func testUnlinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithOAuth.unlink(with: .google, subject: "s")) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.unlinkAccountRequests.isEmpty)
    }

    internal func testUnlinkPropagatesFailure() async {
        testAuthManager.unlinkAccountResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithOAuth.unlink(with: .google, subject: "s")) { error in
            XCTAssertTrue(error is StubError)
        }
    }
}
