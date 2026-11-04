import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Locks in the public call shapes of `Privy` — the SDK's entry point — so that a future
/// change to the protocol (e.g. inserting/reordering a parameter, or changing an entry
/// point's type) fails to *compile* instead of silently breaking source compatibility for
/// existing integrators.
///
/// See `LoginWithSiwsAPICompatibilityTests` for the customer-reported regression that motivated
/// this pattern: privy-ios 2.16.0 silently dropped a SIWS call shape.
internal final class PrivyAPICompatibilityTests: XCTestCase {
    @MainActor
    internal func testPublicCallShapesRemainSourceCompatible() {
        PrivyContainer.shared.manager.reset()
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        // `PrivySdk.initialize` fatalErrors on a second call within the process, so we
        // construct the implementation directly, same as the DI-cycle test does.
        let privy: Privy = PrivyImpl()

        // Authentication state
        let _: () async -> Void = privy.awaitReady
        let _: () async -> AuthState = privy.getAuthState
        let _: () -> AuthState = privy.getAuthStateWithoutRefresh
        let _: PrivyUser? = privy.user
        let _: () async -> PrivyUser? = privy.getUser
        let _: AuthState = privy.authState
        let _: AsyncStream<AuthState> = privy.authStateStream

        // Login method entry points
        let _: LoginWithEmail = privy.email
        let _: LoginWithSms = privy.sms
        let _: LoginWithSiwe = privy.siwe
        let _: LoginWithSiws = privy.siws
        let _: LoginWithCustomAccessToken = privy.customJwt
        let _: LoginWithOAuth = privy.oAuth
        let _: LoginWithPasskey = privy.passkey

        // MFA entry point
        let _: PrivyMfa = privy.mfa

        // Network recovery
        let _: () async -> Void = privy.onNetworkRestored
    }
}
