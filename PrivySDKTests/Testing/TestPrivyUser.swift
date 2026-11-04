import Foundation
@testable import PrivySDK

/// Minimal `PrivyUser` test double. Only `id` is meaningfully configurable today; every other
/// member fatal-errors if a test exercises it, so a missing stub fails loudly instead of silently
/// returning a placeholder.
internal final class TestPrivyUser: PrivyUser, @unchecked Sendable {
    internal var id: String

    internal init(id: String = "test-user-id") {
        self.id = id
    }

    internal var identityToken: String? { nil }
    internal var createdAt: Date? { nil }
    internal var linkedAccounts: [LinkedAccount] { [] }
    internal var mfaMethods: [MfaMethod] { [] }
    internal var mfa: PrivyUserMfa { notStubbed("mfa") }
    internal var embeddedEthereumWallets: [EmbeddedEthereumWallet] { [] }
    internal var embeddedSolanaWallets: [EmbeddedSolanaWallet] { [] }

    internal func getAccessToken() async throws -> String { notStubbed("getAccessToken") }

    internal func createEthereumWallet(allowAdditional: Bool, timeout: Duration) async throws -> EmbeddedEthereumWallet {
        notStubbed("createEthereumWallet")
    }

    internal func createSolanaWallet(allowAdditional: Bool, timeout: Duration) async throws -> EmbeddedSolanaWallet {
        notStubbed("createSolanaWallet")
    }

    internal func refresh() async throws { notStubbed("refresh") }

    internal func migrateWalletsIfNeeded() async throws { notStubbed("migrateWalletsIfNeeded") }

    internal func logout() { notStubbed("logout") }

    internal func logout() async { notStubbed("logout") }

    internal func generateAuthorizationSignature<T: Encodable>(payload: WalletApiPayload<T>) async throws -> String {
        notStubbed("generateAuthorizationSignature")
    }

    internal func generateAuthorizationSignature(payload: Data) async throws -> String {
        notStubbed("generateAuthorizationSignature")
    }

    private func notStubbed(_ member: String) -> Never {
        fatalError("TestPrivyUser.\(member) was called but isn't stubbed for this test.")
    }
}
