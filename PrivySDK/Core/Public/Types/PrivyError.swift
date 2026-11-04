import Foundation

/// `PrivyError` is the error type returned by all Privy methods.
/// Every one of them has an associated errorCode from the `PrivyErrorCode` enum to describe its details.
public struct PrivyError: LocalizedError {
    /// The error code associated to this particular failure.
    public let errorCode: PrivyErrorCode

    internal init(_ errorCode: PrivyErrorCode) {
        self.errorCode = errorCode
    }

    public var errorDescription: String? {
        switch self.errorCode {
        case .authenticationFailure(let reason):
            return reason.localizedDescription
        case .embeddedWalletFailure(let reason):
            return reason.localizedDescription
        case .initializationFailed:
            return "SDK failed to initialize"
        }
    }

    public var isWalletTimeoutError: Bool {
        switch self.errorCode {
        case .embeddedWalletFailure(reason: .timeout):
            return true
        default:
            return false
        }
    }

    /// A stable, non-sensitive identifier safe for breadcrumbs/logging (no associated values).
    internal var breadcrumbCode: String {
        errorCode.breadcrumbCode
    }
}

/// An enumeration of all the errors  that can be thrown by Privy.
public enum PrivyErrorCode: Sendable {
    /// An authentication or authorization error
    case authenticationFailure(reason: AuthenticationFailureReason)
    /// An error on the embedded wallet
    case embeddedWalletFailure(reason: EmbeddedWalletFailureReason)
    /// Initialization of the SDK failed
    case initializationFailed

    internal var breadcrumbCode: String {
        switch self {
        case .authenticationFailure(let reason): return "authenticationFailure.\(reason.breadcrumbCode)"
        case .embeddedWalletFailure(let reason): return "embeddedWalletFailure.\(reason.breadcrumbCode)"
        case .initializationFailed: return "initializationFailed"
        }
    }

    public enum AuthenticationFailureReason: Sendable {
        /// No custom auth provider was set up before using the methods in `privy.customJwt`
        case noCustomAuthProviderConfigured
        /// The custom auth provider failed to provide a token
        case customAuthProviderReturnedNoToken
        /// No user is currently logged in, which was required for the operation
        case notLoggedIn
        /// The auth token is invalid
        case invalidJwt
        /// The credentails provided for authentication were not valid
        case incorrectCredentials(loginMethod: LoginMethod)
        /// An unknown error was thrown during the authentication process
        case failureDuringAuthentication(error: any Error)
        /// Could not find a linked account of type email for the current user
        case emailNotFound
        /// Could not find a linked account of type phone for the current user
        case phoneNotFound
        /// Passkey creation failed
        case passkeyCreationFailed(String)
        /// Passkey authentication failed
        case passkeyAuthenticationFailed(String)
        /// User cancelled the passkey operation
        case passkeyUserCancelled
        /// No passkey credentials found
        case passkeyNoCredentials
        /// The session has expired or been revoked server-side
        case sessionExpired
        /// Linking or logging in surfaced a conflicting account owned by a different user with a
        /// single login method. Resolve by calling the relevant `transferWithCode` method with the nonce.
        ///
        /// Note: transferring an account only moves the login method itself. It will not transfer any
        /// embedded wallets from the other user — the conflicting user's wallet, if any, remains with
        /// that user and is not merged into the current user's account.
        case accountTransferRequired(nonce: String, conflictingUser: ConflictingUserMetadata)

        internal var localizedDescription: String {
            switch self {
            case .noCustomAuthProviderConfigured:
                "No custom auth provider was set up before using the custom auth method"
            case .customAuthProviderReturnedNoToken:
                "The custom auth provider failed to provide a token"
            case .notLoggedIn:
                "No user is logged in"
            case .invalidJwt:
                "The token is invalid"
            case .incorrectCredentials(let loginMethod):
                "The credentials entered for \(loginMethod) were incorrect"
            case .failureDuringAuthentication(let error):
                "Something went wrong during authentication: \(error)"
            case .emailNotFound:
                "Could not find a linked account of type email for the current user"
            case .phoneNotFound:
                "Could not find a linked account of type phone for the current user"
            case .passkeyCreationFailed(let message):
                "Passkey creation failed: \(message)"
            case .passkeyAuthenticationFailed(let message):
                "Passkey authentication failed: \(message)"
            case .passkeyUserCancelled:
                "User cancelled the passkey operation"
            case .passkeyNoCredentials:
                "No passkey credentials found"
            case .sessionExpired:
                "The session has expired or been revoked"
            case .accountTransferRequired:
                "Account transfer required: a conflicting account is already owned by another user"
            }
        }

        internal var breadcrumbCode: String {
            switch self {
            case .noCustomAuthProviderConfigured: return "noCustomAuthProviderConfigured"
            case .customAuthProviderReturnedNoToken: return "customAuthProviderReturnedNoToken"
            case .notLoggedIn: return "notLoggedIn"
            case .invalidJwt: return "invalidJwt"
            case .incorrectCredentials: return "incorrectCredentials"
            case .failureDuringAuthentication: return "failureDuringAuthentication"
            case .emailNotFound: return "emailNotFound"
            case .phoneNotFound: return "phoneNotFound"
            case .passkeyCreationFailed: return "passkeyCreationFailed"
            case .passkeyAuthenticationFailed: return "passkeyAuthenticationFailed"
            case .passkeyUserCancelled: return "passkeyUserCancelled"
            case .passkeyNoCredentials: return "passkeyNoCredentials"
            case .sessionExpired: return "sessionExpired"
            case .accountTransferRequired: return "accountTransferRequired"
            }
        }
    }

    public enum EmbeddedWalletFailureReason: Sendable {
        /// The wallet operation timed out
        case timeout
        /// Failed to decode the response from the wallet
        case failedToDecodeWalletResponse
        /// Something went wrong during wallet creation
        case creationFailed
        /// The user already has an embedded wallet on this chain, including an imported one, and
        /// `allowAdditional` was `false`.
        case additionalWalletsBlocked
        /// No embedded wallet available
        case noWalletAvailable
        /// Maximum number of wallets reached.
        ///
        /// Never thrown: wallet limits are reported by the API as other errors.
        @available(*, deprecated, message: "Never thrown. Wallet limits are reported by the API as other errors. Will be removed in a future major version.")
        case maxNumberOfAdditionalWallet(count: Int)
        /// An unsupported chain was specified
        case unsupportedChain
        /// RPC URL for the chain was not found
        case rpcUrlNotFound
        /// The underlying secure context failed to load
        case secureContextFailed
        /// Invalid parameters for the requested RPC
        case invalidRpcParams(method: String, desription: String)
        /// An error was returned by the JSON RPC call
        case jsonRpcError(message: String)
        /// An error was returned by the RPC call
        case rpcError
        /// The wallet does not support the RPC call made
        case unsupportedRPC(rpcMethod: String)
        /// Failed to parse the encoded Solana transaction
        case invalidSolanaTransaction(details: String)
        /// MFA verification is required before performing this wallet operation
        case missingOrInvalidMfa
        /// The MFA prompt timed out without the user completing verification
        case timeoutOnMfa
        /// The MFA challenge expired before verification was completed
        case mfaChallengeExpired
        /// The maximum number of MFA verification attempts was reached
        case mfaVerificationMaxAttemptsReached
        /// One or more wallets failed to migrate
        case walletMigrationFailed(errors: [any Error])
        /// An error was returned by the embedded wallet iframe
        case iframeError(type: String, message: String)
        /// A signer management operation failed
        case signerError(message: String)
        /// A transaction history operation failed
        case transactionError(message: String)
        /// The app's embedded wallet configuration doesn't support wallet import, which requires user-controlled server wallets
        case importNotSupported
        /// The address of the wallet to import is not a valid address for the chain
        case invalidAddress
        /// The private key to import is not valid for the chain
        case invalidPrivateKey
        /// The seed phrase to import is not a valid English BIP-39 seed phrase
        case invalidSeedPhrase
        /// The address of the wallet to import doesn't match the wallet its secret controls
        case addressMismatch
        /// The wallet to import already exists
        case walletAlreadyExists
        /// A wallet import operation failed
        case importFailed(message: String)

        internal var localizedDescription: String {
            switch self {
            case .timeout:
                "The wallet call timed out"
            case .failedToDecodeWalletResponse:
                "Unable to decode the wallet response"
            case .creationFailed:
                "Failed to create wallet."
            case .additionalWalletsBlocked:
                "Attempted to create an HD wallet but `allowAdditional: true` was not specified."
            case .noWalletAvailable:
                "No embedded wallets have been created for this user."
            case .maxNumberOfAdditionalWallet(let count):
                "You have already created the maximum number of wallets (\(count))."
            case .unsupportedChain:
                "This chain is unsupported."
            case .rpcUrlNotFound:
                "RPC url was not found"
            case .secureContextFailed:
                "Failed to load the secure context."
            case .invalidRpcParams(let rpcMethod, let description):
                "Invalid parameters provided for the \(rpcMethod) RPC: \(description)"
            case .jsonRpcError(let message):
                "JSON RPC error: \(message)"
            case .rpcError:
                "RPC error."
            case .invalidSolanaTransaction(let details):
                "Failed to parse the given Solana transaction: \(details)"
            case .unsupportedRPC(let rpcMethod):
                "This wallet does not support the method: \(rpcMethod)"
            case .missingOrInvalidMfa:
                "MFA verification is required before performing this wallet operation."
            case .timeoutOnMfa:
                "The MFA prompt timed out without the user completing verification."
            case .mfaChallengeExpired:
                "The MFA challenge expired before verification was completed."
            case .mfaVerificationMaxAttemptsReached:
                "The maximum number of MFA verification attempts was reached."
            case .walletMigrationFailed(let errors):
                "One or more wallets failed to migrate: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
            case .iframeError(let type, let message):
                "Embedded wallet iframe error (\(type)): \(message)"
            case .signerError(let message):
                message
            case .transactionError(let message):
                message
            case .importNotSupported:
                "Wallet import requires the app to use user-controlled server wallets."
            case .invalidAddress:
                "The address is not valid for this chain."
            case .invalidPrivateKey:
                "The private key is not valid for this chain."
            case .invalidSeedPhrase:
                "The seed phrase is not a valid English BIP-39 seed phrase."
            case .addressMismatch:
                "The address does not match the wallet to import."
            case .walletAlreadyExists:
                "This wallet has already been imported."
            case .importFailed(let message):
                message
            }
        }

        internal var breadcrumbCode: String {
            switch self {
            case .timeout: return "timeout"
            case .failedToDecodeWalletResponse: return "failedToDecodeWalletResponse"
            case .creationFailed: return "creationFailed"
            case .additionalWalletsBlocked: return "additionalWalletsBlocked"
            case .noWalletAvailable: return "noWalletAvailable"
            case .maxNumberOfAdditionalWallet: return "maxNumberOfAdditionalWallet"
            case .unsupportedChain: return "unsupportedChain"
            case .rpcUrlNotFound: return "rpcUrlNotFound"
            case .secureContextFailed: return "secureContextFailed"
            case .invalidRpcParams: return "invalidRpcParams"
            case .jsonRpcError: return "jsonRpcError"
            case .rpcError: return "rpcError"
            case .unsupportedRPC: return "unsupportedRPC"
            case .invalidSolanaTransaction: return "invalidSolanaTransaction"
            case .missingOrInvalidMfa: return "missingOrInvalidMfa"
            case .timeoutOnMfa: return "timeoutOnMfa"
            case .mfaChallengeExpired: return "mfaChallengeExpired"
            case .mfaVerificationMaxAttemptsReached: return "mfaVerificationMaxAttemptsReached"
            case .walletMigrationFailed: return "walletMigrationFailed"
            case .iframeError: return "iframeError"
            case .signerError: return "signerError"
            case .transactionError: return "transactionError"
            case .importNotSupported: return "importNotSupported"
            case .invalidAddress: return "invalidAddress"
            case .invalidPrivateKey: return "invalidPrivateKey"
            case .invalidSeedPhrase: return "invalidSeedPhrase"
            case .addressMismatch: return "addressMismatch"
            case .walletAlreadyExists: return "walletAlreadyExists"
            case .importFailed: return "importFailed"
            }
        }
    }
}
