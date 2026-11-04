import Foundation

/// Methods used to login with an ethereum wallet, or link one to a user, via Sign-In with Ethereum (SIWE).
public protocol LoginWithSiwe: Sendable {
    /// Generates a SIWE message for the user to sign in order to prove ownership of the wallet.
    ///
    /// - Parameters:
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address to build the SIWE message
    ///
    /// - Returns: A unique SIWE message as a string
    ///
    /// - Throws: An error if there was an issue generating the message
    func generateMessage(params: SiweMessageParams) async throws -> String

    /// Generates a SIWE message for the user to sign in order to prove ownership of the wallet.
    ///
    /// - Parameters:
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address to build the SIWE message
    ///
    /// - Returns: A unique SIWE message as a string
    ///
    /// - Throws: An error if there was an issue generating the message
    @available(*, deprecated, renamed: "generateMessage", message: "Use generateMessage instead, which has identical functionality but simpler naming")
    func generateSiweMessage(params: SiweMessageParams) async throws -> String

    /// Log in the user with the SIWE signature
    ///
    /// - Parameters:
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    ///   - metadata: (Optional) Additional metadata specifying wallet client and connector type.  If omitted, the metadata specified  in "generateMessage" will be used, if applicable.
    ///
    /// - Returns: The authenticated Privy user
    ///
    /// - Throws: An error if authenticating the user is unsuccessful
    func login(
        message: String,
        signature: String,
        params: SiweMessageParams,
        metadata: WalletLoginMetadata?
    ) async throws -> PrivyUser

    /// Log in the user with the SIWE signature
    ///
    /// - Parameters:
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    ///   - metadata: (Optional) Additional metadata specifying wallet client and connector type.  If omitted, the metadata specified  in "generateSiweMessage" will be used, if applicable.
    ///
    /// - Returns: The authenticated Privy user
    ///
    /// - Throws: An error if authenticating the user is unsuccessful
    @available(*, deprecated, renamed: "login", message: "Use login instead, which has identical functionality but simpler naming")
    func loginWithSiwe(
        message: String,
        signature: String,
        params: SiweMessageParams,
        metadata: WalletLoginMetadata?
    ) async throws -> PrivyUser

    /// Links the user's external Ethereum wallet to the users account. User must be authenticated prior to calling this method.
    ///
    /// - Parameters:
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    ///   - metadata: (Optional) Additional metadata specifying wallet client and connector type.  If omitted, the metadata specified  in "generateMessage" will be used, if applicable.
    ///
    /// - Returns: The updated Privy user with the newly linked wallet
    ///
    /// - Throws: An error if linking the user's wallet in is unsuccessful, or if there is no authenticated user
    func link(
        message: String,
        signature: String,
        params: SiweMessageParams,
        metadata: WalletLoginMetadata?
    ) async throws -> PrivyUser

    /// Unlinks an external wallet from the user's account. Ensure that the user is authenticated before calling this function.
    ///
    /// - Parameters:
    ///   - address: The address of the wallet to unlink
    ///
    /// - Returns: The updated Privy user after unlinking the wallet
    func unlink(address: String) async throws -> PrivyUser

    /// Transfers an Ethereum wallet account from another Privy user to the currently authenticated
    /// user. Call this after catching a `PrivyError` with reason `.accountTransferRequired` from `link`.
    ///
    /// The caller must generate a fresh SIWE message and signature before invoking this method.
    ///
    /// - Parameters:
    ///   - nonce: The one-time transfer nonce from the `accountTransferRequired` error
    ///   - message: The SIWE message that was signed by the user's wallet
    ///   - signature: The EIP-191 personal sign signature
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address used to generate the SIWE message. Only `chainId` is read by the transfer endpoint; the other fields are accepted for API symmetry with `link`.
    ///   - metadata: (Optional) Additional metadata specifying wallet client and connector type
    ///
    /// - Returns: The updated Privy user after transferring the wallet account
    ///
    /// - Throws: An error if transferring the account is unsuccessful
    func transferAccount(
        nonce: String,
        message: String,
        signature: String,
        params: SiweMessageParams,
        metadata: WalletLoginMetadata?
    ) async throws -> PrivyUser

    /// Links the user's external Ethereum wallet to the users account. User must be authenticated prior to calling this method.
    ///
    /// - Parameters:
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    ///   - metadata: (Optional) Additional metadata specifying wallet client and connector type.  If omitted, the metadata specified  in "generateSiweMessage" will be used, if applicable.
    ///
    /// - Returns: The updated Privy user with the newly linked wallet
    ///
    /// - Throws: An error if linking the user's wallet in is unsuccessful, or if there is no authenticated user
    @available(*, deprecated, renamed: "link", message: "Use link instead, which has identical functionality but simpler naming")
    func linkWithSiwe(
        message: String,
        signature: String,
        params: SiweMessageParams,
        metadata: WalletLoginMetadata?
    ) async throws -> PrivyUser
}

public extension LoginWithSiwe {
    /// Convenience method that delegates to login with optional values set to nil
    ///
    /// - Parameters:
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    func login(message: String, signature: String, params: SiweMessageParams) async throws -> PrivyUser {
        try await login(message: message, signature: signature, params: params, metadata: nil)
    }

    /// Convenience method that delegates to loginWithSiwe with optional values set to nil
    ///
    /// - Parameters:
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    @available(*, deprecated, renamed: "login", message: "Use login instead, which has identical functionality but simpler naming")
    func loginWithSiwe(message: String, signature: String, params: SiweMessageParams) async throws -> PrivyUser {
        try await login(message: message, signature: signature, params: params, metadata: nil)
    }

    /// Convenience method that delegates to link with optional values set to nil
    ///
    /// - Parameters:
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    func link(message: String, signature: String, params: SiweMessageParams) async throws -> PrivyUser {
        try await link(message: message, signature: signature, params: params, metadata: nil)
    }

    /// Convenience method that delegates to linkWithSiwe with optional values set to nil
    ///
    /// - Parameters:
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    @available(*, deprecated, renamed: "link", message: "Use link instead, which has identical functionality but simpler naming")
    func linkWithSiwe(message: String, signature: String, params: SiweMessageParams) async throws -> PrivyUser {
        try await link(message: message, signature: signature, params: params, metadata: nil)
    }

    /// Convenience method that delegates to transferAccount with optional values set to nil
    ///
    /// - Parameters:
    ///   - nonce: The one-time transfer nonce from the `accountTransferRequired` error
    ///   - message: The previously generated SIWE message
    ///   - signature: The SIWE signature generated from the EIP-191 personal sign request
    ///   - params: Specifies the app domain, app uri, chainId, and wallet address
    func transferAccount(nonce: String, message: String, signature: String, params: SiweMessageParams) async throws -> PrivyUser {
        try await transferAccount(nonce: nonce, message: message, signature: signature, params: params, metadata: nil)
    }
}
