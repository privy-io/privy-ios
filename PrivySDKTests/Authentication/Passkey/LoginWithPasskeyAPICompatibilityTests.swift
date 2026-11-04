import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Locks in the public call shapes of `LoginWithPasskey` so that a future change to the
/// protocol (e.g. inserting/reordering a parameter) fails to *compile* instead of silently
/// breaking source compatibility for existing integrators.
internal final class LoginWithPasskeyAPICompatibilityTests: XCTestCase {
    @MainActor
    internal func testPublicCallShapesRemainSourceCompatible() {
        PrivyContainer.shared.manager.reset()
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        let passkey: LoginWithPasskey = resolve(\PrivyContainer.loginWithPasskey)

        let _: (String, String?) async throws -> PrivyUser = passkey.signup(relyingParty:displayName:)
        let _: (String) async throws -> PrivyUser = passkey.login(relyingParty:)
        let _: (String, String?) async throws -> PrivyUser = passkey.link(relyingParty:displayName:)
        let _: (String) async throws -> PrivyUser = passkey.unlink(credentialId:)
        let _: (String, Bool) async throws -> PrivyUser = passkey.unlink(credentialId:removeAsMfa:)
    }
}
