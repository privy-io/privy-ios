import Foundation

internal protocol AuthRefreshService: Actor {
    /// Attemtps to refresh a session with the current session's auth tokens.
    /// - Parameters:
    ///   - authToken: The current session's auth token
    ///   - refreshToken: The current session's refresh token
    /// - Returns: The updated auth session
    /// - Throws: An error if session not successfully refreshed
    ///
    func refreshAuth(authToken: String, refreshToken: String) async throws -> AuthResponse
}
