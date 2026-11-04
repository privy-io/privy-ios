import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class LoginWithCustomAccessTokenImplTests: PrivyTestCase {
    private var testAuthManager: TestAuthManager!

    override internal func setUp() {
        super.setUp()
        let testAuthManager = TestAuthManager()
        register(\PrivyContainer.authManager) { testAuthManager }
        self.testAuthManager = testAuthManager
    }

    /// Re-registers the container's config with the given token provider, then resolves the
    /// login type under test (which reads the config when it is constructed).
    private func makeLoginWithCustomAccessToken(tokenProvider: TokenProvider?) -> LoginWithCustomAccessToken {
        let config = PrivyConfig(
            appId: "test-app-id",
            appClientId: "test-client-id",
            customAuthConfig: tokenProvider.map { PrivyLoginWithCustomAuthConfig(tokenProvider: $0) }
        )
        register(\PrivyContainer.config) { config }
        return resolve(\PrivyContainer.loginWithCustomAccessToken)
    }

    internal func testLoginSucceedsWithProvidedToken() async throws {
        testAuthManager.loginResult = .success(TestPrivyUser(id: "custom-auth-user"))
        let loginWithCustomAccessToken = makeLoginWithCustomAccessToken { "provider-token" }

        let user = try await loginWithCustomAccessToken.loginWithCustomAccessToken()

        XCTAssertEqual(user.id, "custom-auth-user")
        guard case .customAccessToken(let token) = testAuthManager.loginRequests.first else {
            return XCTFail("Expected a .customAccessToken login request")
        }
        XCTAssertEqual(token, "provider-token")
    }

    internal func testLoginThrowsWhenNoProviderConfigured() async {
        let loginWithCustomAccessToken = makeLoginWithCustomAccessToken(tokenProvider: nil)

        await XCTAssertThrowsErrorAsync(try await loginWithCustomAccessToken.loginWithCustomAccessToken()) { error in
            guard case .authenticationFailure(.noCustomAuthProviderConfigured) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.noCustomAuthProviderConfigured), got \(error)")
            }
        }
        XCTAssertTrue(testAuthManager.loginRequests.isEmpty)
    }

    internal func testLoginThrowsWhenProviderReturnsNoToken() async {
        let loginWithCustomAccessToken = makeLoginWithCustomAccessToken { nil }

        await XCTAssertThrowsErrorAsync(try await loginWithCustomAccessToken.loginWithCustomAccessToken()) { error in
            guard case .authenticationFailure(.customAuthProviderReturnedNoToken) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.customAuthProviderReturnedNoToken), got \(error)")
            }
        }
        XCTAssertTrue(testAuthManager.loginRequests.isEmpty)
    }

    internal func testLoginPropagatesTokenProviderFailure() async {
        struct ProviderError: Error {}
        let loginWithCustomAccessToken = makeLoginWithCustomAccessToken { throw ProviderError() }

        await XCTAssertThrowsErrorAsync(try await loginWithCustomAccessToken.loginWithCustomAccessToken()) { error in
            XCTAssertTrue(error is ProviderError)
        }
        XCTAssertTrue(testAuthManager.loginRequests.isEmpty)
    }

    internal func testLoginPropagatesAuthManagerFailure() async {
        struct LoginError: Error {}
        testAuthManager.loginResult = .failure(LoginError())
        let loginWithCustomAccessToken = makeLoginWithCustomAccessToken { "provider-token" }

        await XCTAssertThrowsErrorAsync(try await loginWithCustomAccessToken.loginWithCustomAccessToken()) { error in
            XCTAssertTrue(error is LoginError)
        }
    }
}
