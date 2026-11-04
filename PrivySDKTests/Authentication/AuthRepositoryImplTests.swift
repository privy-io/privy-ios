import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Covers `AuthRepositoryImpl`'s request construction and error/response mapping. The repository is
/// exercised through the real `URLRequest.execute()` and `backendErrorInterceptor`, with only the
/// transport stubbed (`StubURLProtocol`) and request building faked (`TestNetworkService`).
internal final class AuthRepositoryImplTests: PrivyTestCase {
    private var testNetworkService: TestNetworkService!
    private var authRepository: AuthRepository!

    private static let userJson = #"{"id": "user-1", "created_at": 1700000000, "linked_accounts": [], "mfa_methods": []}"#

    override internal func setUp() {
        super.setUp()
        StubURLProtocol.install()
        let testNetworkService = TestNetworkService()
        register(\PrivyContainer.networkService) { testNetworkService }
        self.testNetworkService = testNetworkService
        self.authRepository = resolve(\PrivyContainer.authRepository)
    }

    override internal func tearDown() {
        StubURLProtocol.uninstall()
        super.tearDown()
    }

    // MARK: sendOtp

    internal func testSendOtpEmailPostsToPasswordlessInit() async throws {
        StubURLProtocol.nextStub = .json(#"{"success": true}"#)

        try await authRepository.sendOtp(to: .email(email: "user@privy.io"))

        XCTAssertEqual(testNetworkService.makeRequestCalls, [.init(path: "/api/v1/passwordless/init", token: nil, httpMethod: "POST")])
        XCTAssertEqual(try lastBody(), ["email": "user@privy.io"])
    }

    internal func testSendOtpPhonePostsToPasswordlessSmsInit() async throws {
        StubURLProtocol.nextStub = .json(#"{"success": true}"#)

        try await authRepository.sendOtp(to: .phone("+15555550100"))

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/passwordless_sms/init")
        XCTAssertEqual(try lastBody(), ["phoneNumber": "+15555550100"])
    }

    internal func testSendOtpUnsuccessfulEmailThrowsIncorrectCredentialsForEmail() async {
        StubURLProtocol.nextStub = .json(#"{"success": false}"#)

        await XCTAssertThrowsErrorAsync(try await authRepository.sendOtp(to: .email(email: "user@privy.io"))) { error in
            assertAuthenticationFailure(error) {
                if case .incorrectCredentials(.email) = $0 { true } else { false }
            }
        }
    }

    internal func testSendOtpUnsuccessfulPhoneThrowsIncorrectCredentialsForPhone() async {
        StubURLProtocol.nextStub = .json(#"{"success": false}"#)

        await XCTAssertThrowsErrorAsync(try await authRepository.sendOtp(to: .phone("+15555550100"))) { error in
            assertAuthenticationFailure(error) {
                if case .incorrectCredentials(.phone) = $0 { true } else { false }
            }
        }
    }

    // MARK: authenticate

    internal func testAuthenticateEmailSendsCredentialsAndDecodesSetAction() async throws {
        StubURLProtocol.nextStub = .json(Self.authJson(action: "set", token: "access", refreshToken: "refresh"))

        let response = try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/passwordless/authenticate")
        XCTAssertNil(testNetworkService.makeRequestCalls.first?.token)
        XCTAssertEqual(try lastBody(), ["email": "user@privy.io", "code": "123456"])
        XCTAssertEqual(response.user.id, "user-1")
        guard case .set(let accessToken, let refreshToken, _) = response.sessionUpdateAction else {
            return XCTFail("Expected a .set session update action")
        }
        XCTAssertEqual(accessToken, "access")
        XCTAssertEqual(refreshToken, "refresh")
    }

    internal func testAuthenticateAppleOAuthIncludesRawCodeType() async throws {
        StubURLProtocol.nextStub = .json(Self.authJson(action: "clear"))

        _ = try await authRepository.authenticate(
            with: .oauth(provider: .apple, authorizationCode: "auth-code", codeVerifier: "verifier", stateCode: "state")
        )

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/oauth/authenticate")
        XCTAssertEqual(
            try lastBody(),
            ["authorization_code": "auth-code", "code_verifier": "verifier", "state_code": "state", "code_type": "raw"]
        )
    }

    internal func testAuthenticateNonAppleOAuthOmitsCodeType() async throws {
        StubURLProtocol.nextStub = .json(Self.authJson(action: "clear"))

        _ = try await authRepository.authenticate(
            with: .oauth(provider: .google, authorizationCode: "auth-code", codeVerifier: "verifier", stateCode: "state")
        )

        XCTAssertEqual(try lastBody(), ["authorization_code": "auth-code", "code_verifier": "verifier", "state_code": "state"])
    }

    internal func testAuthenticateCustomAccessTokenUsesCustomJwtAccountPath() async throws {
        StubURLProtocol.nextStub = .json(Self.authJson(action: "clear"))

        _ = try await authRepository.authenticate(with: .customAccessToken(token: "jwt"))

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/custom_jwt_account/authenticate")
        XCTAssertEqual(try lastBody(), ["token": "jwt"])
    }

    internal func testAuthenticateMapsUnknownSessionUpdateActionToClear() async throws {
        StubURLProtocol.nextStub = .json(Self.authJson(action: "something_new", token: "access", refreshToken: "refresh"))

        let response = try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))

        guard case .clear = response.sessionUpdateAction else {
            return XCTFail("Expected unknown action to fall back to .clear")
        }
    }

    internal func testAuthenticateSetActionMissingRefreshTokenFallsBackToClear() async throws {
        StubURLProtocol.nextStub = .json(Self.authJson(action: "set", token: "access"))

        let response = try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))

        guard case .clear = response.sessionUpdateAction else {
            return XCTFail("Expected a .set action without a refresh token to fall back to .clear")
        }
    }

    internal func testAuthenticateWrapsApiErrorAsFailureDuringAuthentication() async {
        StubURLProtocol.nextStub = .json(#"{"error": "Invalid code", "code": "invalid_credentials"}"#, statusCode: 400)

        await XCTAssertThrowsErrorAsync(try await authRepository.authenticate(with: .email("user@privy.io", code: "bad"))) { error in
            assertAuthenticationFailure(error) {
                guard case .failureDuringAuthentication(let underlying) = $0,
                      case .apiError(let httpCode, let errorCode, let description)? = underlying as? ApiError else {
                    return false
                }
                return httpCode == 400 && errorCode == "invalid_credentials" && description == "Invalid code"
            }
        }
    }

    internal func testAuthenticateWrapsNonJsonErrorBodyAsNetworkError() async {
        StubURLProtocol.nextStub = .json("<html>Bad Gateway</html>", statusCode: 502)

        await XCTAssertThrowsErrorAsync(try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))) { error in
            assertAuthenticationFailure(error) {
                guard case .failureDuringAuthentication(let underlying) = $0,
                      case .networkError(let responseCode, _)? = underlying as? ApiError else {
                    return false
                }
                return responseCode == 502
            }
        }
    }

    internal func testAuthenticateWrapsTransportErrorAsFailureDuringAuthentication() async {
        StubURLProtocol.nextStub = .failure(URLError(.notConnectedToInternet))

        await XCTAssertThrowsErrorAsync(try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))) { error in
            assertAuthenticationFailure(error) {
                if case .failureDuringAuthentication(let underlying) = $0 { (underlying as? URLError)?.code == .notConnectedToInternet } else { false }
            }
        }
    }

    internal func testAuthenticateWrapsMalformedSuccessBodyAsDecodingError() async {
        StubURLProtocol.nextStub = .json(#"{"unexpected": true}"#)

        await XCTAssertThrowsErrorAsync(try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))) { error in
            assertAuthenticationFailure(error) {
                if case .failureDuringAuthentication(let underlying) = $0, case .decodingError? = underlying as? ApiError { true } else { false }
            }
        }
    }

    internal func testAuthenticateSurfacesAccountTransferBackendErrorUnwrapped() async {
        StubURLProtocol.nextStub = .json(Self.accountTransferErrorJson, statusCode: 422)

        await XCTAssertThrowsErrorAsync(try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))) { error in
            guard let transferError = error as? AccountTransferBackendError else {
                return XCTFail("Expected AccountTransferBackendError, got \(error)")
            }
            XCTAssertEqual(transferError.nonce, "transfer-nonce")
            XCTAssertEqual(transferError.embeddedWalletAddress, "0xwallet")
            XCTAssertEqual(transferError.displayName, "Other Account")
        }
    }

    internal func testAuthenticateAccountTransferCodeWithoutNonceFallsBackToApiError() async {
        StubURLProtocol.nextStub = .json(#"{"error": "Transfer required", "code": "account_transfer_required", "data": {}}"#, statusCode: 422)

        await XCTAssertThrowsErrorAsync(try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))) { error in
            assertAuthenticationFailure(error) {
                if case .failureDuringAuthentication(let underlying) = $0, case .apiError? = underlying as? ApiError { true } else { false }
            }
        }
    }

    internal func testAuthenticatePropagatesRequestConstructionFailureUnwrapped() async {
        testNetworkService.makeRequestError = ApiError.couldNotConstructRequest

        await XCTAssertThrowsErrorAsync(try await authRepository.authenticate(with: .email("user@privy.io", code: "123456"))) { error in
            guard case .couldNotConstructRequest? = error as? ApiError else {
                return XCTFail("Expected ApiError.couldNotConstructRequest, got \(error)")
            }
        }
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    // MARK: link / transfer / unlink

    internal func testLinkSendsBearerTokenToLinkPath() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        let user = try await authRepository.link(with: .phone("+15555550100", code: "123456"), authToken: "auth-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls, [.init(path: "/api/v1/passwordless_sms/link", token: "auth-token", httpMethod: "POST")])
        XCTAssertEqual(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer auth-token")
        XCTAssertEqual(try lastBody(), ["phoneNumber": "+15555550100", "code": "123456"])
        XCTAssertEqual(user.id, "user-1")
    }

    internal func testLinkPropagatesApiErrorUnwrapped() async {
        StubURLProtocol.nextStub = .json(#"{"error": "Already linked", "code": "linked_to_another_user"}"#, statusCode: 409)

        await XCTAssertThrowsErrorAsync(try await authRepository.link(with: .email("user@privy.io", code: "123456"), authToken: "auth-token")) { error in
            guard case .apiError(let httpCode, let errorCode, _)? = error as? ApiError else {
                return XCTFail("Expected ApiError.apiError, got \(error)")
            }
            XCTAssertEqual(httpCode, 409)
            XCTAssertEqual(errorCode, "linked_to_another_user")
        }
    }

    internal func testLinkSurfacesAccountTransferBackendError() async {
        StubURLProtocol.nextStub = .json(Self.accountTransferErrorJson, statusCode: 422)

        await XCTAssertThrowsErrorAsync(try await authRepository.link(with: .email("user@privy.io", code: "123456"), authToken: "auth-token")) { error in
            XCTAssertEqual((error as? AccountTransferBackendError)?.nonce, "transfer-nonce")
        }
    }

    internal func testTransferEmailIncludesNonce() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.transfer(with: .email(address: "user@privy.io", code: "123456", nonce: "transfer-nonce"), authToken: "auth-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/passwordless/transfer")
        XCTAssertEqual(try lastBody(), ["email": "user@privy.io", "code": "123456", "nonce": "transfer-nonce"])
    }

    internal func testTransferAppleOAuthIncludesRawCodeTypeAndNonce() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.transfer(
            with: .oauth(provider: .apple, authorizationCode: "auth-code", codeVerifier: "verifier", stateCode: "state", nonce: "transfer-nonce"),
            authToken: "auth-token"
        )

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/oauth/transfer")
        XCTAssertEqual(
            try lastBody(),
            ["authorization_code": "auth-code", "code_verifier": "verifier", "state_code": "state", "code_type": "raw", "nonce": "transfer-nonce"]
        )
    }

    internal func testTransferSiwsOmitsUnsetWalletMetadata() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.transfer(
            with: .siws(message: "msg", signature: "sig", walletAddress: "SoLAddr", walletClientType: nil, connectorType: nil, nonce: "transfer-nonce"),
            authToken: "auth-token"
        )

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/siws/transfer")
        XCTAssertEqual(
            try lastBody(),
            ["address": "SoLAddr", "message": "msg", "message_type": "plain", "signature": "sig", "nonce": "transfer-nonce"]
        )
    }

    internal func testUnlinkEmailSendsAddressToUnlinkPath() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.unlink(with: .email(address: "user@privy.io"), authToken: "auth-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls, [.init(path: "/api/v1/passwordless/unlink", token: "auth-token", httpMethod: "POST")])
        XCTAssertEqual(try lastBody(), ["address": "user@privy.io"])
    }

    internal func testUnlinkOAuthSendsProviderAndSubject() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.unlink(with: .oauth(provider: .discord, subject: "subject-1"), authToken: "auth-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/oauth/unlink")
        XCTAssertEqual(try lastBody(), ["provider": "discord", "subject": "subject-1"])
    }

    internal func testUnlinkPasskeyUsesSnakeCaseBodyAndMfaHeader() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.unlinkPasskey(credentialId: "cred-1", removeAsMfa: true, authToken: "auth-token", mfaToken: "mfa-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/passkeys/unlink")
        XCTAssertEqual(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "privy-mfa-token"), "mfa-token")
        let body = try lastBodyObject()
        XCTAssertEqual(body["credential_id"] as? String, "cred-1")
        XCTAssertEqual(body["remove_as_mfa"] as? Bool, true)
    }

    internal func testUnlinkPasskeyWithoutMfaTokenOmitsHeader() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.unlinkPasskey(credentialId: "cred-1", removeAsMfa: false, authToken: "auth-token", mfaToken: nil)

        XCTAssertNil(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "privy-mfa-token"))
    }

    // MARK: sessions and user

    internal func testRefreshSessionSendsRefreshTokenWithAccessTokenAsBearer() async throws {
        StubURLProtocol.nextStub = .json(Self.authJson(action: "set", token: "new-access", refreshToken: "new-refresh"))

        let response = try await authRepository.refreshSession(token: "old-access", refreshToken: "old-refresh")

        XCTAssertEqual(testNetworkService.makeRequestCalls, [.init(path: "/api/v1/sessions", token: "old-access", httpMethod: "POST")])
        XCTAssertEqual(try lastBody(), ["refresh_token": "old-refresh"])
        guard case .set(let accessToken, _, _) = response.sessionUpdateAction else {
            return XCTFail("Expected a .set session update action")
        }
        XCTAssertEqual(accessToken, "new-access")
    }

    internal func testRefreshSessionPropagatesApiErrorUnwrapped() async {
        StubURLProtocol.nextStub = .json(#"{"error": "Invalid refresh token", "code": "invalid_refresh_token"}"#, statusCode: 401)

        await XCTAssertThrowsErrorAsync(try await authRepository.refreshSession(token: "old-access", refreshToken: "old-refresh")) { error in
            guard case .apiError(let httpCode, _, _)? = error as? ApiError else {
                return XCTFail("Expected ApiError.apiError, got \(error)")
            }
            XCTAssertEqual(httpCode, 401)
        }
    }

    internal func testRefreshUserIssuesGetAndDecodesIdentityToken() async throws {
        StubURLProtocol.nextStub = .json(#"{"user": \#(Self.userJson), "identity_token": "identity"}"#)

        let response = try await authRepository.refreshUser(token: "auth-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls, [.init(path: "/api/v1/users/me", token: "auth-token", httpMethod: "GET")])
        XCTAssertEqual(response.user.id, "user-1")
        XCTAssertEqual(response.identityToken, "identity")
    }

    internal func testLogoutSessionSucceedsOnEmptyObject() async throws {
        StubURLProtocol.nextStub = .json("{}")

        try await authRepository.logoutSession(authToken: "auth-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls, [.init(path: "/api/v1/sessions/logout", token: "auth-token", httpMethod: "POST")])
    }

    internal func testLogoutSessionPropagatesServerError() async {
        StubURLProtocol.nextStub = .json(#"{"error": "Unauthorized", "code": "invalid_auth_token"}"#, statusCode: 401)

        await XCTAssertThrowsErrorAsync(try await authRepository.logoutSession(authToken: "auth-token")) { error in
            guard case .apiError(let httpCode, let errorCode, _)? = error as? ApiError else {
                return XCTFail("Expected ApiError.apiError, got \(error)")
            }
            XCTAssertEqual(httpCode, 401)
            XCTAssertEqual(errorCode, "invalid_auth_token")
        }
    }

    // MARK: updates

    internal func testUpdateEmailUsesCamelCaseBody() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.updateEmail(from: "old@privy.io", to: "new@privy.io", with: "123456", authToken: "auth-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/passwordless/update")
        XCTAssertEqual(try lastBody(), ["oldAddress": "old@privy.io", "newAddress": "new@privy.io", "code": "123456"])
    }

    internal func testUpdatePhoneNumberUsesLegacySnakeCaseBody() async throws {
        StubURLProtocol.nextStub = .json(Self.userJson)

        _ = try await authRepository.updatePhoneNumber(from: "+15555550100", to: "+15555550101", with: "123456", authToken: "auth-token")

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/passwordless_sms/update")
        XCTAssertEqual(try lastBody(), ["old_phone_number": "+15555550100", "new_phone_number": "+15555550101", "code": "123456"])
    }

    // MARK: SIWE / OAuth init

    internal func testGenerateSiweMessageDecodesResponse() async throws {
        StubURLProtocol.nextStub = .json(#"{"nonce": "siwe-nonce", "address": "0xabc", "expires_at": "2026-10-21T00:00:00Z"}"#)

        let response = try await authRepository.generateSiweMessage(walletAddress: "0xabc")

        XCTAssertEqual(testNetworkService.makeRequestCalls.first?.path, "/api/v1/siwe/init")
        XCTAssertEqual(try lastBody(), ["address": "0xabc"])
        XCTAssertEqual(response.nonce, "siwe-nonce")
        XCTAssertEqual(response.expiresAt, "2026-10-21T00:00:00Z")
    }

    internal func testGenerateOAuthUrlSendsProviderAndPkceParameters() async throws {
        StubURLProtocol.nextStub = .json(#"{"url": "https://accounts.example.com/authorize"}"#)

        let response = try await authRepository.generateOAuthUrl(
            oAuthInitRequest: OAuthInitRequest(
                provider: .twitter,
                redirectUri: "app://callback",
                codeChallenge: "challenge",
                stateCode: "state",
                authToken: "auth-token"
            )
        )

        XCTAssertEqual(testNetworkService.makeRequestCalls, [.init(path: "/api/v1/oauth/init", token: "auth-token", httpMethod: "POST")])
        XCTAssertEqual(
            try lastBody(),
            ["provider": "twitter", "redirect_to": "app://callback", "code_challenge": "challenge", "state_code": "state"]
        )
        XCTAssertEqual(response.url, "https://accounts.example.com/authorize")
    }

    // MARK: helpers

    private static let accountTransferErrorJson = """
    {
        "error": "Account transfer required",
        "code": "account_transfer_required",
        "data": {
            "nonce": "transfer-nonce",
            "account": {"displayName": "Other Account"},
            "otherUser": {"embeddedWalletAddress": "0xwallet"}
        }
    }
    """

    private static func authJson(action: String, token: String? = nil, refreshToken: String? = nil) -> String {
        var fields = [#""user": \#(userJson)"#, #""session_update_action": "\#(action)""#]
        if let token { fields.append(#""token": "\#(token)""#) }
        if let refreshToken { fields.append(#""refresh_token": "\#(refreshToken)""#) }
        return "{\(fields.joined(separator: ", "))}"
    }

    private func lastBodyObject() throws -> [String: Any] {
        let body = try XCTUnwrap(StubURLProtocol.requests.last?.httpBody, "No request body recorded")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private func lastBody() throws -> [String: String] {
        try lastBodyObject().compactMapValues { $0 as? String }
    }
}

private func assertAuthenticationFailure(
    _ error: Error,
    file: StaticString = #filePath,
    line: UInt = #line,
    matches predicate: (PrivyErrorCode.AuthenticationFailureReason) -> Bool
) {
    guard let privyError = error as? PrivyError, case .authenticationFailure(let reason) = privyError.errorCode else {
        return XCTFail("Expected PrivyError.authenticationFailure, got \(error)", file: file, line: line)
    }
    XCTAssertTrue(predicate(reason), "Unexpected authentication failure reason: \(reason)", file: file, line: line)
}
