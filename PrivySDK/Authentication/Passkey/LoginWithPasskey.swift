import Foundation

/// Methods used to login with a passkey or register a new passkey account.
public protocol LoginWithPasskey: Sendable {
    /// Registers a new passkey and logs the user in.
    ///
    /// - Parameters:
    ///   - relyingParty: The origin that owns the credentials (e.g., "https://yourdomain.com")
    ///   - displayName: Optional user-friendly name shown in the passkey selector
    ///
    /// - Returns: The authenticated Privy user
    ///
    /// - Throws: An error if passkey creation or registration fails
    func signup(relyingParty: String, displayName: String?) async throws -> PrivyUser

    /// Authenticates a user with an existing passkey.
    ///
    /// - Parameters:
    ///   - relyingParty: The origin that owns the credential (e.g., "https://yourdomain.com")
    ///
    /// - Returns: The authenticated Privy user
    ///
    /// - Throws: An error if passkey authentication fails or user cancels
    func login(relyingParty: String) async throws -> PrivyUser

    /// Links a new passkey to an already authenticated user's account.
    ///
    /// - Parameters:
    ///   - relyingParty: The origin that owns the credentials (e.g., "https://yourdomain.com")
    ///   - displayName: Optional user-friendly name shown in the passkey selector
    ///
    /// - Returns: The updated Privy user with the newly linked passkey
    ///
    /// - Throws: An error if passkey creation or linking fails, or if there is no authenticated user
    func link(relyingParty: String, displayName: String?) async throws -> PrivyUser

    /// Unlinks a passkey account from a currently authenticated user's account.
    ///
    /// - Parameters:
    ///   - credentialId: The credential ID of the passkey to unlink from the user.
    ///   - removeAsMfa: Whether to also remove the passkey as an MFA method. Defaults to `true`.
    /// - Returns: The updated Privy user after unlinking the passkey
    /// - Throws: An error if unlinking the user's passkey is unsuccessful, or if there is no authenticated user.
    func unlink(credentialId: String, removeAsMfa: Bool) async throws -> PrivyUser
}

public extension LoginWithPasskey {
    /// Unlinks a passkey account from a currently authenticated user's account.
    ///
    /// - Parameters:
    ///   - credentialId: The credential ID of the passkey to unlink from the user.
    /// - Returns: The updated Privy user after unlinking the passkey
    /// - Throws: An error if unlinking the user's passkey is unsuccessful, or if there is no authenticated user.
    func unlink(credentialId: String) async throws -> PrivyUser {
        try await unlink(credentialId: credentialId, removeAsMfa: true)
    }
}
