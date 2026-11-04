@testable import PrivySDK

/// Deterministic `PKCEHelper` test double, so tests can assert on the exact verifier, challenge and
/// state the OAuth flow hands to the backend.
internal final class TestPKCEHelper: PKCEHelper, @unchecked Sendable {
    internal static let codeVerifier = "test-code-verifier"
    internal static let stateCode = "test-state-code"

    internal func generateCodeVerifier() -> String { Self.codeVerifier }

    internal func generateStateCode() -> String { Self.stateCode }

    internal func deriveCodeChallenge(from codeVerifier: String) -> String { "challenge-for-\(codeVerifier)" }
}
