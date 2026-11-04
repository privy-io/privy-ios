import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Locks in the public call shapes of `LoginWithSms` so that a future change to the
/// protocol (e.g. inserting/reordering a parameter) fails to *compile* instead of silently
/// breaking source compatibility for existing integrators.
internal final class LoginWithSmsAPICompatibilityTests: XCTestCase {
    @MainActor
    internal func testPublicCallShapesRemainSourceCompatible() {
        PrivyContainer.shared.manager.reset()
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        let sms: LoginWithSms = resolve(\PrivyContainer.loginWithSms)

        let _: (String) async throws -> Void = sms.sendCode(to:)
        let _: (String, String) async throws -> PrivyUser = sms.loginWithCode(_:sentTo:)
        let _: (String, String) async throws -> PrivyUser = sms.linkWithCode(_:sentTo:)
        let _: (String, String) async throws -> Void = sms.updateWithCode(_:sentTo:)
        let _: (String) async throws -> PrivyUser = sms.unlink(phoneNumber:)
        let _: (String, String, String) async throws -> PrivyUser = sms.transferWithCode(nonce:code:sentTo:)
    }
}
