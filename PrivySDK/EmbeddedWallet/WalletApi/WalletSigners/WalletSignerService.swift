import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var walletSignerService: Factory<WalletSignerService> {
        self { WalletSignerServiceImpl() }.shared
    }
}

/// Service responsible for managing additional signers on wallets.
internal protocol WalletSignerService: Sendable {
    /// Adds signers to a wallet by merging them with existing signers.
    ///
    /// Validates that the wallet is on the TEE stack, fetches the current
    /// signer list, merges the new signers, and updates the wallet.
    /// After success the user data is automatically refreshed.
    ///
    /// - Parameters:
    ///   - wallet: The embedded wallet to add signers to.
    ///   - signers: The signers to add.
    ///
    /// - Throws: ``PrivyError`` if the wallet is not a TEE wallet or the API calls fail.
    func addSigners(to wallet: EmbeddedWallet, signers: [SignerInput]) async throws

    /// Removes a signer from a wallet by filtering it out of the existing signers list.
    ///
    /// Validates that the wallet is on the TEE stack, fetches the current
    /// signer list, filters out the matching signer, and updates the wallet.
    /// After success the user data is automatically refreshed.
    ///
    /// - Parameters:
    ///   - wallet: The embedded wallet to remove the signer from.
    ///   - signerId: The identifier of the signer to remove.
    ///
    /// - Throws: ``PrivyError`` if the wallet is not a TEE wallet or the API calls fail.
    func removeSigner(from wallet: EmbeddedWallet, signerId: String) async throws

    /// Removes all signers from a wallet by setting the signers list to empty.
    ///
    /// Validates that the wallet is on the TEE stack and updates the wallet
    /// with an empty signers list.
    /// After success the user data is automatically refreshed.
    ///
    /// - Parameters:
    ///   - wallet: The embedded wallet to remove all signers from.
    ///
    /// - Throws: ``PrivyError`` if the wallet is not a TEE wallet or the API calls fail.
    func removeAllSigners(from wallet: EmbeddedWallet) async throws
}

private final class WalletSignerServiceImpl: WalletSignerService {
    private let walletApi: WalletApiRepository = resolve(\PrivyContainer.walletApiRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    internal func addSigners(to wallet: EmbeddedWallet, signers: [SignerInput]) async throws {
        let walletType = wallet.chainType.rawValue.capitalized
        logger.debug("addSigners called on \(walletType) wallet \(wallet.address)")

        guard wallet.isTEEWallet else {
            logger.error("addSigners failed: wallet \(wallet.address) is not a TEE wallet (recoveryMethod: \(wallet.recoveryMethod ?? "nil"))", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "addSigners requires a TEE wallet.")))
        }

        guard let walletId = wallet.id else {
            logger.error("addSigners failed: wallet \(wallet.address) has no ID", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "addSigners requires a wallet with an ID.")))
        }

        guard !signers.isEmpty else {
            logger.error("addSigners called with empty signers array", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "At least one signer is required.")))
        }

        let signerIds = signers.map(\.signerId)
        logger.info("Adding \(signers.count) signer(s) to wallet \(walletId): \(signerIds)")

        do {
            let auth = try await authManager.refreshSessionIfNeeded()
            let token = auth.authToken

            // Fetch current wallet to retrieve existing signers
            logger.debug("Fetching current wallet state for \(walletId)")
            let currentWallet = try await walletApi.getWallet(walletId: walletId, token: token)
            logger.debug("Wallet \(walletId) has \(currentWallet.additionalSigners.count) existing signer(s)")

            // Convert existing signers to params
            let existingSigners = currentWallet.additionalSigners.map { signer in
                AdditionalSignerParam(
                    signerId: signer.signerId,
                    overridePolicyIds: signer.overridePolicyIds
                )
            }

            // Convert new signers to params
            let newSigners = signers.map { signer in
                AdditionalSignerParam(
                    signerId: signer.signerId,
                    overridePolicyIds: signer.policyIds
                )
            }

            // Merge existing + new (no dedup, matching React SDK behavior)
            let mergedSigners = existingSigners + newSigners
            logger.debug("Updating wallet \(walletId) with \(mergedSigners.count) total signer(s)")

            // PATCH with merged list
            let request = WalletApiUpdateWalletRequest(additionalSigners: mergedSigners)
            let _ = try await walletApi.updateWallet(
                walletId: walletId,
                params: request,
                token: token
            )

            let _ = try await authManager.refreshUser()
            logger.info("Successfully added \(signers.count) signer(s) to wallet \(walletId), user refreshed")
        } catch {
            logger.error("addSigners failed for \(walletType) wallet \(walletId)", error: error)
            throw error
        }
    }

    internal func removeSigner(from wallet: EmbeddedWallet, signerId: String) async throws {
        let walletType = wallet.chainType.rawValue.capitalized
        logger.debug("removeSigner called on \(walletType) wallet \(wallet.address) for signer \(signerId)")

        guard wallet.isTEEWallet else {
            logger.error("removeSigner failed: wallet \(wallet.address) is not a TEE wallet (recoveryMethod: \(wallet.recoveryMethod ?? "nil"))", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "removeSigner requires a TEE wallet.")))
        }
        guard let walletId = wallet.id else {
            logger.error("removeSigner failed: wallet \(wallet.address) has no ID", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "removeSigner requires a wallet with an ID.")))
        }

        logger.info("Removing signer \(signerId) from wallet \(walletId)")

        do {
            let auth = try await authManager.refreshSessionIfNeeded()
            let token = auth.authToken

            // Fetch current wallet to retrieve existing signers
            logger.debug("Fetching current wallet state for \(walletId)")
            let currentWallet = try await walletApi.getWallet(walletId: walletId, token: token)
            logger.debug("Wallet \(walletId) has \(currentWallet.additionalSigners.count) existing signer(s)")

            // Verify the signer exists before attempting removal
            guard currentWallet.additionalSigners.contains(where: { $0.signerId == signerId }) else {
                logger.error("removeSigner failed: signer \(signerId) not found on wallet \(walletId)", error: nil)
                throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "Signer \(signerId) not found on wallet.")))
            }

            // Filter out the signer to remove
            let filteredSigners = currentWallet.additionalSigners
                .filter { $0.signerId != signerId }
                .map { AdditionalSignerParam(signerId: $0.signerId, overridePolicyIds: $0.overridePolicyIds) }

            logger.debug("Updating wallet \(walletId) with \(filteredSigners.count) remaining signer(s)")

            // PATCH with filtered list
            let request = WalletApiUpdateWalletRequest(additionalSigners: filteredSigners)
            let _ = try await walletApi.updateWallet(
                walletId: walletId,
                params: request,
                token: token
            )

            let _ = try await authManager.refreshUser()
            logger.info("Successfully removed signer \(signerId) from wallet \(walletId), user refreshed")
        } catch {
            logger.error("removeSigner failed for \(walletType) wallet \(walletId)", error: error)
            throw error
        }
    }

    internal func removeAllSigners(from wallet: EmbeddedWallet) async throws {
        let walletType = wallet.chainType.rawValue.capitalized
        logger.debug("removeAllSigners called on \(walletType) wallet \(wallet.address)")

        guard wallet.isTEEWallet else {
            logger.error("removeAllSigners failed: wallet \(wallet.address) is not a TEE wallet (recoveryMethod: \(wallet.recoveryMethod ?? "nil"))", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "removeAllSigners requires a TEE wallet.")))
        }
        guard let walletId = wallet.id else {
            logger.error("removeAllSigners failed: wallet \(wallet.address) has no ID", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "removeAllSigners requires a wallet with an ID.")))
        }

        logger.info("Removing all signers from wallet \(walletId)")

        do {
            let auth = try await authManager.refreshSessionIfNeeded()
            let token = auth.authToken

            // PATCH with empty list — no need to GET first
            let request = WalletApiUpdateWalletRequest(additionalSigners: [])
            let _ = try await walletApi.updateWallet(
                walletId: walletId,
                params: request,
                token: token
            )

            let _ = try await authManager.refreshUser()
            logger.info("Successfully removed all signers from wallet \(walletId), user refreshed")
        } catch {
            logger.error("removeAllSigners failed for \(walletType) wallet \(walletId)", error: error)
            throw error
        }
    }
}
