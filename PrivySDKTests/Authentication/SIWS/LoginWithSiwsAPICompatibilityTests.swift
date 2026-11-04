import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Locks in the public call shapes of `LoginWithSiws` so that a future change to the
/// protocol (e.g. inserting/reordering a parameter) fails to *compile* instead of silently
/// breaking source compatibility for existing integrators.
internal final class LoginWithSiwsAPICompatibilityTests: XCTestCase {
    @MainActor
    internal func testPublicCallShapesRemainSourceCompatible() {
        PrivyContainer.shared.manager.reset()
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        let siws: LoginWithSiws = resolve(\PrivyContainer.loginWithSiws)

        // login
        let _: (String, String) async throws -> PrivyUser = siws.login(message:signature:)
        let _: (String, String, SiwsMessageParams) async throws -> PrivyUser = siws.login(message:signature:params:)
        let _: (String, String, WalletLoginMetadata?) async throws -> PrivyUser = siws.login(message:signature:metadata:)
        let _: (String, String, SiwsMessageParams?, WalletLoginMetadata?) async throws -> PrivyUser =
            siws.login(message:signature:params:metadata:)

        // link
        let _: (String, String) async throws -> PrivyUser = siws.link(message:signature:)
        let _: (String, String, SiwsMessageParams) async throws -> PrivyUser = siws.link(message:signature:params:)
        let _: (String, String, WalletLoginMetadata?) async throws -> PrivyUser = siws.link(message:signature:metadata:)
        let _: (String, String, SiwsMessageParams?, WalletLoginMetadata?) async throws -> PrivyUser =
            siws.link(message:signature:params:metadata:)

        // unlink
        let _: (String) async throws -> PrivyUser = siws.unlink(address:)

        // transferAccount
        let _: (String, String, String, SiwsMessageParams) async throws -> PrivyUser =
            siws.transferAccount(nonce:message:signature:params:)
        let _: (String, String, String, SiwsMessageParams, WalletLoginMetadata?) async throws -> PrivyUser =
            siws.transferAccount(nonce:message:signature:params:metadata:)
    }
}
