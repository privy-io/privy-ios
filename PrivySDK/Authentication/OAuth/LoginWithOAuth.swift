import Foundation
import AuthenticationServices

/// Methods used to login with an OAuth provider, or linking to a user.
public protocol LoginWithOAuth: Sendable {
    /// Logs the user in using the specified OAuth provider.
    ///
    /// - Parameters:
    ///   - provider: The specified OAuthProvider. See the OAuthProvider enum for a full list of supported providers.
    ///   - appUrlScheme: (Optional) your app's url scheme. If you don't specify the URL scheme in the `privy.oAuth.login` call,
    ///                   Privy will use the first valid app URL scheme from your app's info.plist.
    ///
    /// - Returns: New AuthSession if successfully authenticated
    ///
    /// - Throws: An error if authenticating the user in is unsuccessful
    func login(with provider: OAuthProvider, appUrlScheme: String?) async throws -> PrivyUser

    /// Unlinks an OAuth account from the user
    ///
    /// - Parameters:
    ///   - provider: The specified OAuthProvider. See the OAuthProvider enum for a full list of supported providers.
    ///   - subject: The subject of the user's linked OAuth account from the OAuth provider.
    ///
    /// - Returns: The updated Privy user after unlinking the OAuth account
    func unlink(with provider: OAuthProvider, subject: String) async throws -> PrivyUser

    /// Links an OAuth account to the user.
    ///
    /// - Parameters:
    ///   - provider: The specified OAuthProvider. See the OAuthProvider enum for a full list of supported providers.
    ///   - appUrlScheme: (Optional) your app's URL scheme. If you don't specify the URL scheme in the `privy.oAuth.link` call,
    ///                   Privy will use the first valid app URL scheme from your app's info.plist.
    ///
    /// - Throws: An error if authenticating the user in is unsuccessful
    func link(with provider: OAuthProvider, appUrlScheme: String?) async throws -> PrivyUser

    /// Transfers an OAuth account from another Privy user to the currently authenticated user. Call
    /// this after catching a `PrivyError` with reason `.accountTransferRequired` from `link`.
    ///
    /// A fresh OAuth browser flow is launched to produce new credentials, which are submitted together
    /// with the one-time nonce from the error.
    ///
    /// - Parameters:
    ///   - nonce: The one-time transfer nonce from the `accountTransferRequired` error
    ///   - provider: The specified OAuthProvider. See the OAuthProvider enum for a full list of supported providers.
    ///   - appUrlScheme: (Optional) your app's url scheme. If you don't specify the URL scheme in the `privy.oAuth.transferAccount` call,
    ///                   Privy will use the first valid app URL scheme from your app's info.plist.
    ///
    /// - Returns: The updated Privy user after transferring the OAuth account
    ///
    /// - Throws: An error if transferring the account is unsuccessful
    func transferAccount(nonce: String, with provider: OAuthProvider, appUrlScheme: String?) async throws -> PrivyUser
}

public extension LoginWithOAuth {
    /// Convenience function that delegates to login(with provider: OAuthProvider, appUrlScheme: String?) without having to specify appUrlScheme.
    func login(with provider: OAuthProvider) async throws -> PrivyUser {
        return try await self.login(with: provider, appUrlScheme: nil)
    }

    /// Convenience function that delegates to link(with provider: OAuthProvider, appUrlScheme: String?) without having to specify appUrlScheme.
    func link(with provider: OAuthProvider) async throws -> PrivyUser {
        return try await self.link(with: provider, appUrlScheme: nil)
    }

    /// Convenience function that delegates to transferAccount(nonce:with:appUrlScheme:) without having to specify appUrlScheme.
    func transferAccount(nonce: String, with provider: OAuthProvider) async throws -> PrivyUser {
        return try await self.transferAccount(nonce: nonce, with: provider, appUrlScheme: nil)
    }
}
