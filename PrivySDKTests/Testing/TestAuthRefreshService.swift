import Foundation
@testable import PrivySDK

/// In-memory `AuthRefreshService` test double. `refreshAuth` fatal-errors unless a result has been
/// configured, so a test that forgets to stub it fails loudly instead of silently refreshing.
internal actor TestAuthRefreshService: AuthRefreshService {
    internal var refreshAuthResult: Result<AuthResponse, Error>?
    internal private(set) var refreshAuthRequests: [(authToken: String, refreshToken: String)] = []
    private var refreshHook: (@Sendable () -> Void)?

    /// Sets the result `refreshAuth` returns. Actor-isolated, so tests configure it with `await`.
    internal func stub(_ result: Result<AuthResponse, Error>) {
        refreshAuthResult = result
    }

    /// Runs after the request is recorded and before the result is returned, so a test can change
    /// state while a refresh is in flight.
    internal func onRefresh(_ hook: @escaping @Sendable () -> Void) {
        refreshHook = hook
    }

    internal func refreshAuth(authToken: String, refreshToken: String) async throws -> AuthResponse {
        refreshAuthRequests.append((authToken, refreshToken))
        refreshHook?()
        guard let refreshAuthResult else {
            fatalError("TestAuthRefreshService.refreshAuth was called but isn't stubbed for this test.")
        }
        return try refreshAuthResult.get()
    }
}
