import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Locks in the public call shapes of `LoginWithSiwe` so that a future change to the
/// protocol (e.g. inserting/reordering a parameter) fails to *compile* instead of silently
/// breaking source compatibility for existing integrators.
internal final class LoginWithSiweAPICompatibilityTests: XCTestCase {
    @MainActor
    internal func testPublicCallShapesRemainSourceCompatible() {
        PrivyContainer.shared.manager.reset()
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        let siwe: LoginWithSiwe = resolve(\PrivyContainer.loginWithSiwe)

        // generateMessage
        let _: (SiweMessageParams) async throws -> String = siwe.generateMessage(params:)
        let _: (SiweMessageParams) async throws -> String = siwe.generateSiweMessage(params:)

        // login
        let _: (String, String, SiweMessageParams) async throws -> PrivyUser = siwe.login(message:signature:params:)
        let _: (String, String, SiweMessageParams, WalletLoginMetadata?) async throws -> PrivyUser =
            siwe.login(message:signature:params:metadata:)
        let _: (String, String, SiweMessageParams) async throws -> PrivyUser = siwe.loginWithSiwe(message:signature:params:)
        let _: (String, String, SiweMessageParams, WalletLoginMetadata?) async throws -> PrivyUser =
            siwe.loginWithSiwe(message:signature:params:metadata:)

        // link
        let _: (String, String, SiweMessageParams) async throws -> PrivyUser = siwe.link(message:signature:params:)
        let _: (String, String, SiweMessageParams, WalletLoginMetadata?) async throws -> PrivyUser =
            siwe.link(message:signature:params:metadata:)
        let _: (String, String, SiweMessageParams) async throws -> PrivyUser = siwe.linkWithSiwe(message:signature:params:)
        let _: (String, String, SiweMessageParams, WalletLoginMetadata?) async throws -> PrivyUser =
            siwe.linkWithSiwe(message:signature:params:metadata:)

        // unlink
        let _: (String) async throws -> PrivyUser = siwe.unlink(address:)

        // transferAccount
        let _: (String, String, String, SiweMessageParams) async throws -> PrivyUser =
            siwe.transferAccount(nonce:message:signature:params:)
        let _: (String, String, String, SiweMessageParams, WalletLoginMetadata?) async throws -> PrivyUser =
            siwe.transferAccount(nonce:message:signature:params:metadata:)
    }
}
