import Foundation
internal import FactoryKit

internal protocol WalletMigrationManager: Sendable {
    func migrateWalletsIfNeeded() async throws
}

extension PrivyContainer {
    internal var walletMigrationManager: Factory<WalletMigrationManager> {
        self { WalletMigrationManagerImpl() }.shared
    }
}

private final class WalletMigrationManagerImpl: WalletMigrationManager {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let appConfigRepository: AppConfigRepository = resolve(\PrivyContainer.appConfigRepository)
    private let webViewWalletConnector: WebViewWalletConnector = resolve(\PrivyContainer.webViewWalletConnector)
    private let handler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)
    private let logger: Logger = resolve(\PrivyContainer.logger)
    private let breadcrumbEmitter: BreadcrumbEmitter = resolve(\PrivyContainer.breadcrumbEmitter)

    func migrateWalletsIfNeeded() async throws {
        // 1. Get authenticated session and linked accounts
        let auth = try await authManager.refreshSessionIfNeeded()
        let linkedAccounts = auth.user.linkedAccounts

        // 2. Separate wallets into imported vs HD (non-imported) wallets
        let ethWallets = linkedAccounts.getEmbeddedWalletAccounts(chainType: .ethereum)
        let solWallets = linkedAccounts.getEmbeddedWalletAccounts(chainType: .solana)
        let allWallets: [any EmbeddedWalletAccount] = ethWallets + solWallets

        let importedWallets = allWallets.filter { $0.imported }
        let hdWallets = allWallets.filter { !$0.imported }

        // 3. Get primary wallet, check if already on TEE stack
        let primaryWallet = try? linkedAccounts.getPrimaryWalletForEntropyInfo()

        // 4. Check if any wallets actually need migration (early exit if not)
        let hdWalletsNeedMigration = !hdWallets.isEmpty && !(primaryWallet?.isTEEWallet ?? true)
        let importedNeedMigration = importedWallets.contains { !$0.isTEEWallet }

        guard hdWalletsNeedMigration || importedNeedMigration else {
            logger.verbose("No wallets to migrate, skipping migration.")
            return
        }

        // 5. Only then check app config for TEE mode
        let appConfig = try await appConfigRepository.loadAppConfig()
        guard appConfig.embeddedWalletConfig.mode == .userControlledServerWalletsOnly else {
            logger.verbose("App not configured for TEE mode, skipping migration.")
            return
        }

        breadcrumbEmitter.emit(.walletMigrationStarted())

        do {
            // 6. HD wallets: ensurePrimaryEmbeddedWalletConnected() then delegate all together
            var migrationErrors: [any Error] = []
            if hdWalletsNeedMigration, let primaryWallet {
                do {
                    logger.verbose("Migrating HD wallets.")
                    try await webViewWalletConnector.ensurePrimaryEmbeddedWalletConnected()

                    let rootWallet = RootWalletForDelegation(
                        address: primaryWallet.address,
                        chainType: primaryWallet.chainType.rawValue,
                        imported: false
                    )

                    let delegatedWallets = hdWallets.map { wallet in
                        DelegatedWallet(
                            address: wallet.address,
                            chainType: wallet.chainType.rawValue,
                            walletIndex: wallet.hdWalletIndex
                        )
                    }

                    let requestData = DelegateActionsRequestData(
                        accessToken: auth.authToken,
                        rootWallet: rootWallet,
                        delegatedWallets: delegatedWallets
                    )

                    _ = try await handler.delegateActions(data: requestData)
                } catch {
                    logger.error("Failed to migrate HD wallets.", error: error)
                    migrationErrors.append(error)
                }
            }

            // 7. Imported wallets: each gets its own connect + delegate cycle
            for wallet in importedWallets where !wallet.isTEEWallet {
                do {
                    logger.verbose("Migrating imported wallet \(wallet.address).")
                    try await webViewWalletConnector.connectWallet(for: wallet)

                    let rootWallet = RootWalletForDelegation(
                        address: wallet.address,
                        chainType: wallet.chainType.rawValue,
                        imported: true
                    )

                    let delegatedWallet = DelegatedWallet(
                        address: wallet.address,
                        chainType: wallet.chainType.rawValue,
                        walletIndex: wallet.hdWalletIndex
                    )

                    let requestData = DelegateActionsRequestData(
                        accessToken: auth.authToken,
                        rootWallet: rootWallet,
                        delegatedWallets: [delegatedWallet]
                    )

                    _ = try await handler.delegateActions(data: requestData)
                } catch {
                    logger.error("Failed to migrate imported wallet \(wallet.address).", error: error)
                    migrationErrors.append(error)
                }
            }

            // 8. Refresh session to get updated wallet states
            _ = try await authManager.refreshSession()

            // 9. If any wallet failed to migrate, throw an aggregate error
            if !migrationErrors.isEmpty {
                throw PrivyError(.embeddedWalletFailure(reason: .walletMigrationFailed(errors: migrationErrors)))
            }

            breadcrumbEmitter.emit(.walletMigrationCompleted())
        } catch {
            breadcrumbEmitter.emit(.walletMigrationFailed(error: error))
            throw error
        }
    }
}
