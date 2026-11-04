import Foundation
@testable import PrivySDK

/// In-memory `MfaTokenRepository` test double. Backed by a plain stored property since the real
/// implementation is itself just storage with no branching logic worth faking selectively.
internal final class TestMfaTokenRepository: MfaTokenRepository, @unchecked Sendable {
    internal var storedToken: String?
    internal private(set) var deleteCallCount = 0

    internal func save(mfaToken: String) async throws {
        storedToken = mfaToken
    }

    internal func retrieve() async -> String? { storedToken }

    internal func delete() async {
        deleteCallCount += 1
        storedToken = nil
    }
}
