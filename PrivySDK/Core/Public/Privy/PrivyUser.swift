import Foundation

/// The Privy user object
public protocol PrivyUser: Sendable {
    /// The user's Privy ID
    var id: String { get }

    /// The user's ID token
    var identityToken: String? { get }

    /// The point in time at which the logged in user was created.
    /// Value will only be nil if there is no user currently logged in.
    var createdAt: Date? { get }

    /// A list of linked accounts for this user. A linked account can be any of the methods the user
    /// authenticated with, or one of the user's embedded wallets, including imported ones.
    ///
    /// Identify embedded wallets by `id` or `address`, not by `hdWalletIndex`, which isn't unique.
    /// Archived wallets aren't included.
    var linkedAccounts: [LinkedAccount] { get }

    /**
     * A list of MFA methods linked to this user.
     */
    var mfaMethods: [MfaMethod] { get }

    /**
     * MFA namespace for enrollment and verification.
     * Access pattern: `user.mfa.totp.generateSecret()`
     */
    var mfa: PrivyUserMfa { get }

    /// A list of the user's embedded Ethereum wallets, including imported ones. These wallets expose
    /// a "provider" instance which can be used to take wallet actions.
    ///
    /// The list isn't sorted by ``EmbeddedWallet/hdWalletIndex``, which isn't unique. Identify
    /// wallets by ``EmbeddedWallet/id`` or ``EmbeddedWallet/address``. Archived wallets aren't
    /// included.
    var embeddedEthereumWallets: [EmbeddedEthereumWallet] { get }

    /// A list of the user's embedded Solana wallets, including imported ones. These wallets expose
    /// a "provider" instance which can be used to take wallet actions.
    ///
    /// The list isn't sorted by ``EmbeddedWallet/hdWalletIndex``, which isn't unique. Identify
    /// wallets by ``EmbeddedWallet/id`` or ``EmbeddedWallet/address``. Archived wallets aren't
    /// included.
    var embeddedSolanaWallets: [EmbeddedSolanaWallet] { get }

    /**
     * Returns the user's access token, but will first refresh the user session if needed.
     *
     * - Returns: The user's access token
     *
     * - Throws: An error if the user is not currently authenticated, or if refresh fails.
     */
    func getAccessToken() async throws -> String

    /// Creates an embedded Ethereum wallet for the user.
    ///
    /// In apps that use TEE execution, Privy decides which of the user's seed phrases the new
    /// wallet is derived from, or creates a new one. This includes seed phrases the user imported,
    /// on either chain. Imported private keys are never used. The new wallet's
    /// ``EmbeddedWallet/hdWalletIndex`` is assigned by Privy and isn't necessarily one more than
    /// the user's current wallet count, so identify the wallet by ``EmbeddedWallet/id`` or
    /// ``EmbeddedWallet/address``.
    ///
    /// - Parameters:
    ///   - allowAdditional: Whether to create a wallet when the user already has one. Required when
    ///     the user already has an embedded wallet on this chain, including an imported one.
    ///   - timeout: How long to wait for wallet creation on the on-device (webview) stack. Not used
    ///     with TEE execution, where the network layer's timeouts apply.
    ///
    /// - Returns: The newly created `EmbeddedEthereumWallet`.
    ///
    /// - Throws: ``PrivyError`` with an `embeddedWalletFailure` reason of `additionalWalletsBlocked`
    ///   if the user already has an embedded Ethereum wallet, including an imported one, and
    ///   `allowAdditional` is `false`, or with an `authenticationFailure` code if the user is no
    ///   longer authenticated. Errors from Privy, such as wallet limits, are thrown as-is.
    func createEthereumWallet(allowAdditional: Bool, timeout: Duration) async throws -> EmbeddedEthereumWallet

    /// Creates an embedded Solana wallet for the user.
    ///
    /// In apps that use TEE execution, Privy decides which of the user's seed phrases the new
    /// wallet is derived from, or creates a new one. This includes seed phrases the user imported,
    /// on either chain. Imported private keys are never used. The new wallet's
    /// ``EmbeddedWallet/hdWalletIndex`` is assigned by Privy and isn't necessarily one more than
    /// the user's current wallet count, so identify the wallet by ``EmbeddedWallet/id`` or
    /// ``EmbeddedWallet/address``.
    ///
    /// - Parameters:
    ///   - allowAdditional: Whether to create a wallet when the user already has one. Required when
    ///     the user already has an embedded wallet on this chain, including an imported one.
    ///   - timeout: How long to wait for wallet creation on the on-device (webview) stack. Not used
    ///     with TEE execution, where the network layer's timeouts apply.
    ///
    /// - Returns: The newly created `EmbeddedSolanaWallet`.
    ///
    /// - Throws: ``PrivyError`` with an `embeddedWalletFailure` reason of `additionalWalletsBlocked`
    ///   if the user already has an embedded Solana wallet, including an imported one, and
    ///   `allowAdditional` is `false`, or with an `authenticationFailure` code if the user is no
    ///   longer authenticated. Errors from Privy, such as wallet limits, are thrown as-is.
    func createSolanaWallet(allowAdditional: Bool, timeout: Duration) async throws -> EmbeddedSolanaWallet

    /// Imports an existing wallet as an embedded wallet owned by this user.
    ///
    /// Wallet import is only supported when the app uses user-controlled server wallets. The SDK
    /// encrypts the secret on the device before sending it, so it never leaves the device in
    /// plaintext. Privy derives the wallet's address from the secret and rejects the import if it
    /// doesn't match `address`.
    ///
    /// An imported wallet counts as an existing wallet on its chain: to create another wallet on that
    /// chain afterwards, pass `true` for `allowAdditional` to
    /// ``createEthereumWallet(allowAdditional:timeout:)`` or
    /// ``createSolanaWallet(allowAdditional:timeout:)``. Imported private keys are never used to
    /// derive new wallets.
    ///
    /// > Warning: Importing a seed phrase can also make it the source of wallets Privy creates for
    /// > this user later, on any chain. Anyone who holds the phrase can derive those wallets too.
    /// > Only import seed phrases the user controls and hasn't shared.
    ///
    /// - Parameters:
    ///   - chainType: The chain of the wallet to import.
    ///   - address: The address of the wallet to import: a `0x`-prefixed hex address for Ethereum,
    ///     or a base58 address for Solana. Privy checks that it's a valid address for the chain.
    ///   - secret: The secret of the wallet to import. See ``WalletImportSecret`` for the expected
    ///     format on each chain.
    ///
    /// - Returns: The imported wallet: an `EmbeddedEthereumWallet` for Ethereum, or an
    ///   `EmbeddedSolanaWallet` for Solana.
    ///
    /// - Throws: ``PrivyError`` with an `embeddedWalletFailure` reason of `importNotSupported` if the
    ///   app doesn't use user-controlled server wallets, `invalidAddress`, `invalidPrivateKey` or
    ///   `invalidSeedPhrase` if the input isn't valid for the chain, `addressMismatch` if the secret
    ///   doesn't control `address`, `walletAlreadyExists` if the wallet was already imported, or
    ///   `importFailed` if the import fails. Also throws if the user is no longer authenticated.
    func importWallet(
        chainType: WalletImportSupportedChainType,
        address: String,
        secret: WalletImportSecret
    ) async throws -> any EmbeddedWallet

    /**
     * Fetches the latest user info. If the user's session is expired, the session will first be refreshed.
     *
     * - Throws: an error if refreshing the user fails, or if the current user is no longer authenticated
     */
    func refresh() async throws

    /// Migrates the user's embedded wallets to the TEE stack.
    ///
    /// By default, wallet migration happens automatically when a user authenticates.
    /// Use this method to trigger migration manually when `disableAutomaticMigration`
    /// is set to `true`.
    ///
    /// - Throws: If the user is not authenticated, or if the migration fails.
    func migrateWalletsIfNeeded() async throws

    /**
     * Ends the session of the logged in Privy user.
     */
    func logout()

    func logout() async

    /**
     * Generates a cryptographic signature for an API request payload using the authenticated user's signing key.
     *
     * > Important: This API is currently in beta and may change in future releases.
     *
     * This method signs the provided payload to generate a base64-encoded authorization signature.
     *
     * Visit https://docs.privy.io/controls/authorization-keys/using-owners/sign/utility-functions for more information
     * on signing requests.
     *
     * - Parameters:
     *   - payload: The `WalletApiPayload` containing the API request details (version, URL, method, headers, and body) to be signed.
     *
     * - Returns: The cryptographic signature as a base64-encoded `String` that can be included in Privy API requests
     *            (e.g., as the `privy-authorization-signature` header).
     *
     * - Throws: If the user is not authenticated, if the user's signer is unavailable, or if signature generation fails.
     */
    func generateAuthorizationSignature<T: Encodable>(
        payload: WalletApiPayload<T>
    ) async throws -> String

    /// Generates a cryptographic signature for a pre-serialized binary payload using the authenticated user's signing key.
    ///
    /// > Important: This API is currently in beta and may change in future releases.
    ///
    /// Unlike the typed payload variant, this method skips JSON canonicalization and signs the raw bytes directly.
    /// Use this when you have already serialized and canonicalized your payload outside the SDK.
    ///
    /// - Parameters:
    ///   - payload: The pre-serialized payload bytes to sign.
    ///
    /// - Returns: The cryptographic signature as a base64-encoded `String` that can be included in Privy API requests
    ///            (e.g., as the `privy-authorization-signature` header).
    ///
    /// - Throws: If the user is not authenticated, if the user's signer is unavailable, or if signature generation fails.
    func generateAuthorizationSignature(
        payload: Data
    ) async throws -> String
}

public extension PrivyUser {
    // These extension function handle allowing allowAdditional and timeout to be optional parameters

    /// Creates an embedded Ethereum wallet for the user, with `allowAdditional` set to `false` and
    /// a 60-second timeout for on-device (webview) creation.
    ///
    /// See ``PrivyUser/createEthereumWallet(allowAdditional:timeout:)`` for how Privy creates the
    /// wallet and how to identify it.
    ///
    /// - Returns: The newly created `EmbeddedEthereumWallet`.
    ///
    /// - Throws: The errors ``PrivyUser/createEthereumWallet(allowAdditional:timeout:)`` throws.
    func createEthereumWallet() async throws -> EmbeddedEthereumWallet {
        return try await self.createEthereumWallet(allowAdditional: false, timeout: .seconds(60))
    }

    /// Creates an embedded Solana wallet for the user, with `allowAdditional` set to `false` and a
    /// 60-second timeout for on-device (webview) creation.
    ///
    /// See ``PrivyUser/createSolanaWallet(allowAdditional:timeout:)`` for how Privy creates the
    /// wallet and how to identify it.
    ///
    /// - Returns: The newly created `EmbeddedSolanaWallet`.
    ///
    /// - Throws: The errors ``PrivyUser/createSolanaWallet(allowAdditional:timeout:)`` throws.
    func createSolanaWallet() async throws -> EmbeddedSolanaWallet {
        return try await self.createSolanaWallet(allowAdditional: false, timeout: .seconds(60))
    }

    /// Creates an embedded Ethereum wallet for the user, with a 60-second timeout for on-device
    /// (webview) creation.
    ///
    /// See ``PrivyUser/createEthereumWallet(allowAdditional:timeout:)`` for how Privy creates the
    /// wallet and how to identify it.
    ///
    /// - Parameters:
    ///   - allowAdditional: Whether to create a wallet when the user already has one. Required when
    ///     the user already has an embedded wallet on this chain, including an imported one.
    ///
    /// - Returns: The newly created `EmbeddedEthereumWallet`.
    ///
    /// - Throws: The errors ``PrivyUser/createEthereumWallet(allowAdditional:timeout:)`` throws.
    func createEthereumWallet(allowAdditional: Bool) async throws -> EmbeddedEthereumWallet {
        return try await self.createEthereumWallet(allowAdditional: allowAdditional, timeout: .seconds(60))
    }

    /// Creates an embedded Solana wallet for the user, with a 60-second timeout for on-device
    /// (webview) creation.
    ///
    /// See ``PrivyUser/createSolanaWallet(allowAdditional:timeout:)`` for how Privy creates the
    /// wallet and how to identify it.
    ///
    /// - Parameters:
    ///   - allowAdditional: Whether to create a wallet when the user already has one. Required when
    ///     the user already has an embedded wallet on this chain, including an imported one.
    ///
    /// - Returns: The newly created `EmbeddedSolanaWallet`.
    ///
    /// - Throws: The errors ``PrivyUser/createSolanaWallet(allowAdditional:timeout:)`` throws.
    func createSolanaWallet(allowAdditional: Bool) async throws -> EmbeddedSolanaWallet {
        return try await self.createSolanaWallet(allowAdditional: allowAdditional, timeout: .seconds(60))
    }

    /// Default implementation for types that don't support wallet import. Throws `importNotSupported`.
    func importWallet(
        chainType: WalletImportSupportedChainType,
        address: String,
        secret: WalletImportSecret
    ) async throws -> any EmbeddedWallet {
        throw PrivyError(.embeddedWalletFailure(reason: .importNotSupported))
    }
}
