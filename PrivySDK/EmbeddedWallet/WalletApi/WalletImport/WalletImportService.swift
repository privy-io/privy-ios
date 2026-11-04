import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var walletImportService: Factory<WalletImportService> {
        self { WalletImportServiceImpl() }.shared
    }
}

/// Imports existing wallets into the TEE stack (user-controlled server wallets).
internal protocol WalletImportService: Sendable {
    /// Imports an existing wallet as a TEE embedded wallet owned by the authenticated user.
    ///
    /// The SDK starts the import, encrypts the secret to the key the import returns and submits it.
    /// The secret never leaves the device unencrypted. The import enclave derives the wallet's
    /// address from the secret and rejects the import if it doesn't match `address`.
    ///
    /// - Parameters:
    ///   - secret: The private key or seed phrase of the wallet to import.
    ///   - chainType: The chain of the wallet to import.
    ///   - address: The address of the wallet to import.
    ///
    /// - Returns: The imported wallet, from the refreshed session.
    ///
    /// - Throws: ``PrivyError`` with `.importNotSupported` if the app doesn't use user-controlled
    ///   server wallets, `.invalidAddress`, `.invalidPrivateKey` or `.invalidSeedPhrase` if the input
    ///   isn't valid, `.addressMismatch` if the secret doesn't control `address`,
    ///   `.walletAlreadyExists` if the wallet was already imported, or `.importFailed` otherwise.
    ///   Other ``PrivyError``s, such as authentication failures, are passed through.
    func importWallet(
        _ secret: WalletImportSecret,
        chainType: WalletImportSupportedChainType,
        address: String
    ) async throws -> any EmbeddedWalletAccount
}

private final class WalletImportServiceImpl: WalletImportService {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let appConfigRepository: AppConfigRepository = resolve(\PrivyContainer.appConfigRepository)
    private let hpkeEncryptor: HPKEEncryptor = resolve(\PrivyContainer.hpkeEncryptor)
    private let walletApi: WalletApiRepository = resolve(\PrivyContainer.walletApiRepository)
    private let breadcrumbEmitter: BreadcrumbEmitter = resolve(\PrivyContainer.breadcrumbEmitter)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    internal func importWallet(
        _ secret: WalletImportSecret,
        chainType: WalletImportSupportedChainType,
        address: String
    ) async throws -> any EmbeddedWalletAccount {
        breadcrumbEmitter.emit(.walletImportStarted(chainType: chainType))
        do {
            let wallet = try await performImport(secret, chainType: chainType, address: address)
            breadcrumbEmitter.emit(.walletImportCompleted(chainType: chainType))
            return wallet
        } catch let error as CancellationError {
            breadcrumbEmitter.emit(.walletImportFailed(chainType: chainType, error: error))
            throw error
        } catch {
            let importError = mapImportError(error)
            logger.error("Error importing \(chainType) wallet.", error: importError)
            breadcrumbEmitter.emit(.walletImportFailed(chainType: chainType, error: importError))
            throw importError
        }
    }

    private func performImport(
        _ secret: WalletImportSecret,
        chainType: WalletImportSupportedChainType,
        address: String
    ) async throws -> any EmbeddedWalletAccount {
        // The server doesn't check this for user sessions, so an import into an app that doesn't
        // use user-controlled server wallets would otherwise succeed
        let appConfig = try await appConfigRepository.loadAppConfig()
        guard case .userControlledServerWalletsOnly = appConfig.embeddedWalletConfig.mode else {
            throw PrivyError(.embeddedWalletFailure(reason: .importNotSupported))
        }

        let auth = try await authManager.refreshSessionIfNeeded()

        let initRequest = WalletApiImportInitRequest(
            address: address,
            chainType: chainType,
            entropyType: secret.entropyType,
            encryptionType: .hpke,
            index: secret.index
        )
        let initResponse = try await walletApi.initImport(initRequest, token: auth.authToken)
        let sealedPayload = try hpkeEncryptor.seal(secret.plaintext, recipientPublicKey: initResponse.encryptionPublicKey.data)

        let submitRequest = WalletApiImportSubmitRequest(
            wallet: WalletApiImportSubmitRequest.Wallet(
                address: address,
                chainType: chainType,
                entropyType: secret.entropyType,
                encryptionType: .hpke,
                index: secret.index,
                encapsulatedKey: Base64Data(sealedPayload.encapsulatedKey),
                ciphertext: Base64Data(sealedPayload.ciphertext)
            )
        )
        let importedWalletId = try await walletApi.submitImport(submitRequest, token: auth.authToken).id

        // Fetching the user with a valid token, rather than refreshing the session, sees the
        // imported wallet and doesn't log the user out if the request fails
        _ = try await authManager.refreshSessionIfNeeded()
        let updatedUser = try await authManager.refreshUser()
        guard let wallet = updatedUser.linkedAccounts.getEmbeddedWalletAccount(id: importedWalletId) else {
            throw PrivyError(.embeddedWalletFailure(reason: .importFailed(message: "The imported wallet was not found after refreshing the user.")))
        }
        return wallet
    }

    /// Wraps any error that isn't a ``PrivyError`` into one.
    private func mapImportError(_ error: any Error) -> any Error {
        if let privyError = error as? PrivyError {
            return privyError
        }

        if let apiError = error as? ApiError, case .apiError(let httpCode, _, let description) = apiError {
            if (400 ..< 500).contains(httpCode), let reason = failureReason(forServerMessage: description) {
                return PrivyError(.embeddedWalletFailure(reason: reason))
            }
            return PrivyError(.embeddedWalletFailure(reason: .importFailed(message: "Wallet import failed: \(description)")))
        }

        return PrivyError(.embeddedWalletFailure(reason: .importFailed(message: "Wallet import failed: \(error.localizedDescription)")))
    }

    /// The backend returns the same `invalid_data` code for every import failure, so the reason is
    /// recognized from the message.
    private func failureReason(forServerMessage message: String) -> PrivyErrorCode.EmbeddedWalletFailureReason? {
        let lowercasedMessage = message.lowercased()
        if lowercasedMessage.contains("wallet already exists") {
            return .walletAlreadyExists
        }
        if lowercasedMessage.contains("does not match the address derived") {
            return .addressMismatch
        }
        // "Failed to derive address from decrypted private key" (Ethereum) and "Failed to derive
        // Solana keypair from decrypted private key"
        if lowercasedMessage.contains("decrypted private key") {
            return .invalidPrivateKey
        }
        // "Failed to derive address from decrypted seed phrase"
        if lowercasedMessage.contains("decrypted seed phrase") {
            return .invalidSeedPhrase
        }
        // "Invalid address for specified chain type."
        if lowercasedMessage.contains("invalid address") {
            return .invalidAddress
        }
        return nil
    }
}
