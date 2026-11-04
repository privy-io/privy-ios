import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var authRefreshService: Factory<AuthRefreshService> {
        self { AuthRefreshServiceImpl() }.shared
    }
}

/// AuthRefreshService is a Swfit Actor type. Swift Actor types are thread safe and prevents data races
/// by serializing all access to it's mutable properties / methods. It's important to use an Actor here
/// because we can leverage it's internal serial queue to ensure 4 simultaneous refresh requests do not trigger 4 API calls.
/// Only the first refresh request should trigger an API call, and all subsequent requests should wait for that API call's response.
private actor AuthRefreshServiceImpl: AuthRefreshService {
//    @Injected(\PrivyContainer.authRepository) private var authRepository: AuthRepository

    // A map where the key is current auth tokens and the value is
    // a Task that's refreshing the session using those tokens.
    // Access to this map is serialized because the class is an Actor type
    private var tasks = [AuthTokens: Task<AuthResponse, Error>]()

    internal func refreshAuth(authToken: String, refreshToken: String) async throws -> AuthResponse {
        let tokens = AuthTokens(authToken: authToken, refreshToken: refreshToken)

        if let task = tasks[tokens] {
            // If there is already a Task refreshing the session with the given tokens, wait for it's result
            return try await task.value
        }

        // Create a Task to refresh the session with the provided tokens, and add it to local cache
        let refreshTask = Task {
            try await resolve(\PrivyContainer.authRepository).refreshSession(
                token: tokens.authToken,
                refreshToken: tokens.refreshToken
            )
        }

        // Store Task in cache
        tasks[tokens] = refreshTask

        do {
            // Wait for Task's result
            let result = try await refreshTask.value

            // if response returns sessionUpdateAction == ignore/clear, or if response returns same tokens as request,
            // we don't want to add the response to the local cache
            let sameAuthTokensReturned = result.token == tokens.authToken && result.refreshToken == tokens.refreshToken
            if result.sessionUpdateAction.shouldEvictFromCache || sameAuthTokensReturned {
                tasks[tokens] = nil
            }

            return result
        } catch {
            // if the refresh task throws, we should allow it to try again, as it could be a temporary error
            tasks[tokens] = nil
            throw error
        }
    }
}

private struct AuthTokens: Hashable {
    let authToken: String
    let refreshToken: String
}
