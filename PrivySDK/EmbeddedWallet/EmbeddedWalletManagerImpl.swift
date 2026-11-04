import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var embeddedWalletManager: Factory<EmbeddedWalletManager> {
        self { EmbeddedWalletManagerImpl() }.shared
    }
}

private final class EmbeddedWalletManagerImpl: EmbeddedWalletManager {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let logger: Logger = resolve(\PrivyContainer.logger)
    private let config: PrivyConfig = resolve(\PrivyContainer.config)
    private let embeddedWalletStateManager: EmbeddedWalletStateManager = resolve(\PrivyContainer.embeddedWalletStateManager)

    private let appConfigRepository: AppConfigRepository = resolve(\PrivyContainer.appConfigRepository)
    private let walletApi: WalletApiRepository = resolve(\PrivyContainer.walletApiRepository)
    private let breadcrumbEmitter: BreadcrumbEmitter = resolve(\PrivyContainer.breadcrumbEmitter)

    func createWallet(chainType: ChainType, allowAdditional: Bool, timeout: Duration) async throws -> (any EmbeddedWalletAccount) {
        breadcrumbEmitter.emit(.walletCreateStarted(chainType: chainType))

        let createdWallet: CreatedWallet
        do {
            let _ = try authManager.ensureAuthenticated()

            let _ = try await authManager.refreshSessionIfNeeded()

            let appConfig = try await appConfigRepository.loadAppConfig()
            let walletCreator = PrivyContainer.shared.embeddedWalletCreator(appConfig)

            createdWallet = try await walletCreator.createWallet(chainType: chainType, allowAdditional: allowAdditional, timeout: timeout)
        } catch {
            logger.error("Error creating \(chainType) wallet.", error: error)
            breadcrumbEmitter.emit(.walletCreateFailed(chainType: chainType, error: error))
            throw error
        }

        do {
            let updatedAuthSession = try await authManager.refreshSession()

            guard let newlyCreatedWallet = updatedAuthSession.user.linkedAccounts.getEmbeddedWalletAccountByAddress(address: createdWallet.address) else {
                logger.error("New wallet created, but not found in updated auth session.", error: nil)
                throw PrivyError(.embeddedWalletFailure(reason: .creationFailed))
            }

            breadcrumbEmitter.emit(.walletCreateCompleted(chainType: chainType))
            return newlyCreatedWallet
        } catch {
            breadcrumbEmitter.emit(.walletCreateFailed(chainType: chainType, error: error))
            throw error
        }
    }

    func logout() async {
        await self.embeddedWalletStateManager.update(newState: .disconnected)
    }
}
