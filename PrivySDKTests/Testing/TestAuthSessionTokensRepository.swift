import Foundation
@testable import PrivySDK

/// In-memory `AuthSessionTokensRepository` test double. Backed by a plain stored property since
/// the real implementation is itself just keychain-backed storage with no branching logic worth
/// faking selectively.
internal final class TestAuthSessionTokensRepository: AuthSessionTokensRepository, @unchecked Sendable {
    internal var storedTokens: AuthSessionTokens?
    internal private(set) var saveRequests: [AuthSessionTokens] = []
    internal private(set) var deleteCallCount = 0

    internal func save(authTokens auth: AuthSessionTokens) async throws {
        saveRequests.append(auth)
        storedTokens = auth
    }

    internal func retrieveAuthTokens() async -> AuthSessionTokens? { storedTokens }

    internal func deleteAuthTokens() async {
        deleteCallCount += 1
        storedTokens = nil
    }
}
