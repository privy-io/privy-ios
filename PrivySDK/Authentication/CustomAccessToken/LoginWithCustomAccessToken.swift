import Foundation

/// A method calling a custom auth provider and returning an access token.
public typealias TokenProvider = @Sendable () async throws -> String?

/// Methods used to login with an account from a custom provider.
public protocol LoginWithCustomAccessToken: Sendable {
    /**
     Login with custom access token
     # Returns:
     Updated authentication state

     # Code
     ```
     do {
         _ = try await privy.customJwt.loginWithCustomAccessToken()
     } catch {
         print(error)
     }
     ```
     */
    func loginWithCustomAccessToken() async throws -> PrivyUser
}
