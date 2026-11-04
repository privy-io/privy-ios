import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Locks in the public call shapes of `PrivyUser` so that a future change to the
/// protocol (e.g. inserting/reordering a parameter) fails to *compile* instead of silently
/// breaking source compatibility for existing integrators.
///
/// See `LoginWithSiwsAPICompatibilityTests` for the customer-reported regression that motivated
/// this pattern: privy-ios 2.16.0 silently dropped a SIWS call shape.
internal final class PrivyUserAPICompatibilityTests: XCTestCase {
    @MainActor
    internal func testPublicCallShapesRemainSourceCompatible() {
        PrivyContainer.shared.manager.reset()
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        let user: PrivyUser = resolve(\PrivyContainer.privyUser)

        // Properties
        let _: String = user.id
        let _: String? = user.identityToken
        let _: Date? = user.createdAt
        let _: [LinkedAccount] = user.linkedAccounts
        let _: [MfaMethod] = user.mfaMethods
        let _: PrivyUserMfa = user.mfa
        let _: [EmbeddedEthereumWallet] = user.embeddedEthereumWallets
        let _: [EmbeddedSolanaWallet] = user.embeddedSolanaWallets

        // Session / wallet management
        let _: () async throws -> String = user.getAccessToken
        let _: (Bool, Duration) async throws -> EmbeddedEthereumWallet = user.createEthereumWallet(allowAdditional:timeout:)
        let _: (Bool, Duration) async throws -> EmbeddedSolanaWallet = user.createSolanaWallet(allowAdditional:timeout:)
        let _: (WalletImportSupportedChainType, String, WalletImportSecret) async throws -> any EmbeddedWallet =
            user.importWallet(chainType:address:secret:)
        let _: () async throws -> Void = user.refresh
        let _: () async throws -> Void = user.migrateWalletsIfNeeded
        let _: () -> Void = user.logout
        let _: () async -> Void = user.logout

        // Authorization signing
        let _: (WalletApiPayload<String>) async throws -> String = user.generateAuthorizationSignature(payload:)
        let _: (Data) async throws -> String = user.generateAuthorizationSignature(payload:)

        // Wallet import inputs
        let _: [WalletImportSupportedChainType] = [.ethereum, .solana]
        let _: WalletImportSecret = .privateKey(Data())
        let _: WalletImportSecret = .mnemonic("", index: 0)

        // Convenience overloads for wallet creation
        let _: () async throws -> EmbeddedEthereumWallet = user.createEthereumWallet
        let _: () async throws -> EmbeddedSolanaWallet = user.createSolanaWallet
        let _: (Bool) async throws -> EmbeddedEthereumWallet = user.createEthereumWallet(allowAdditional:)
        let _: (Bool) async throws -> EmbeddedSolanaWallet = user.createSolanaWallet(allowAdditional:)
    }

    /// `TestPrivyUser` doesn't implement wallet import, like a conformer written before import was
    /// added, so it compiles and gets the default implementation.
    internal func testConformersWithoutWalletImportGetADefaultThatThrowsImportNotSupported() async {
        let user: PrivyUser = TestPrivyUser()

        await XCTAssertThrowsErrorAsync(
            try await user.importWallet(chainType: .ethereum, address: "", secret: .privateKey(Data()))
        ) { error in
            XCTAssertEqual((error as? PrivyError)?.breadcrumbCode, "embeddedWalletFailure.importNotSupported")
        }
    }
}
