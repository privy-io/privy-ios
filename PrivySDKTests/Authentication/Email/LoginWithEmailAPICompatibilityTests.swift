import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Locks in the public call shapes of `LoginWithEmail` so that a future change to the
/// protocol (e.g. inserting/reordering a parameter) fails to *compile* instead of silently
/// breaking source compatibility for existing integrators.
internal final class LoginWithEmailAPICompatibilityTests: XCTestCase {
    @MainActor
    internal func testPublicCallShapesRemainSourceCompatible() {
        PrivyContainer.shared.manager.reset()
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        let email: LoginWithEmail = resolve(\PrivyContainer.loginWithEmail)

        let _: (String) async throws -> Void = email.sendCode(to:)
        let _: (String, String) async throws -> PrivyUser = email.loginWithCode(_:sentTo:)
        let _: (String, String) async throws -> PrivyUser = email.linkWithCode(_:sentTo:)
        let _: (String, String) async throws -> Void = email.updateWithCode(_:sentTo:)
        let _: (String) async throws -> PrivyUser = email.unlink(email:)
        let _: (String, String, String) async throws -> PrivyUser = email.transferWithCode(nonce:code:sentTo:)
    }
}
