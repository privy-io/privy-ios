import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Locks in the public call shapes of `LoginWithOAuth` so that a future change to the
/// protocol (e.g. inserting/reordering a parameter) fails to *compile* instead of silently
/// breaking source compatibility for existing integrators.
///
internal final class LoginWithOAuthAPICompatibilityTests: XCTestCase {
    @MainActor
    internal func testPublicCallShapesRemainSourceCompatible() {
        PrivyContainer.shared.manager.reset()
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        let oauth: LoginWithOAuth = resolve(\PrivyContainer.loginWithOAuth)

        let _: (OAuthProvider) async throws -> PrivyUser = oauth.login(with:)
        let _: (OAuthProvider, String?) async throws -> PrivyUser = oauth.login(with:appUrlScheme:)
        let _: (OAuthProvider, String) async throws -> PrivyUser = oauth.unlink(with:subject:)
        let _: (OAuthProvider) async throws -> PrivyUser = oauth.link(with:)
        let _: (OAuthProvider, String?) async throws -> PrivyUser = oauth.link(with:appUrlScheme:)
        let _: (String, OAuthProvider) async throws -> PrivyUser = oauth.transferAccount(nonce:with:)
        let _: (String, OAuthProvider, String?) async throws -> PrivyUser = oauth.transferAccount(nonce:with:appUrlScheme:)
    }
}
