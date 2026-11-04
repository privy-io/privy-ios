import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var embeddedWalletCreator: ParameterFactory<AppConfig, EmbeddedWalletCreator> {
        self { appConfig in
            if case .userControlledServerWalletsOnly = appConfig.embeddedWalletConfig.mode {
                WalletApiWalletCreator()
            } else {
                WebViewWalletCreator()
            }
        }.unique
    }
}

internal struct CreatedWallet {
    internal let chainType: ChainType
    internal let address: String
}

/// Protocol used for creating an embedded wallet, based on the app's config for wallet mode
internal protocol EmbeddedWalletCreator: Sendable {
    /// Creates a wallet for the use, in the given chain type and respecting the "additional wallets" HD semantics
    /// - Parameters:
    ///   - chainType: The chain type to create the wallet for
    ///   - allowAdditional: Whether to allow creating additional wallets
    ///   - timeout: The timeout duration for wallet creation
    /// - Throws: If wallet creation fails.
    /// - Returns: The chain type and address of the created wallet
    func createWallet(chainType: ChainType, allowAdditional: Bool, timeout: Duration) async throws -> CreatedWallet
}

private final class WalletApiWalletCreator: EmbeddedWalletCreator {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let walletApi: WalletApiRepository = resolve(\PrivyContainer.walletApiRepository)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    func createWallet(chainType: ChainType, allowAdditional: Bool, timeout: Duration) async throws -> CreatedWallet {
        let _ = try authManager.ensureAuthenticated()

        let auth = try await authManager.refreshSessionIfNeeded()
        // Imported wallets count, the same as in the JS SDKs
        let hasNoWalletsInChain = auth.user.linkedAccounts.getEmbeddedWalletAccounts(chainType: chainType).isEmpty

        guard hasNoWalletsInChain || allowAdditional else {
            throw PrivyError(.embeddedWalletFailure(reason: .additionalWalletsBlocked))
        }

        // The API internally determines the HD-index of the wallet to create
        // Note: timeout parameter is not used for API-based wallet creation as it's handled by the network layer
        let response = try await walletApi.createWallet(.init(chainType: chainType), token: auth.authToken)

        return CreatedWallet(chainType: chainType, address: response.address)
    }
}

private final class WebViewWalletCreator: EmbeddedWalletCreator {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let webViewHandler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)

    func createWallet(chainType: ChainType, allowAdditional: Bool, timeout: Duration) async throws -> CreatedWallet {
        let _ = try authManager.ensureAuthenticated()
        let auth = try await authManager.refreshSessionIfNeeded()

        // Imported wallets count, the same as in the JS SDKs
        let hasNoWalletsInChain = auth.user.linkedAccounts.getEmbeddedWalletAccounts(chainType: chainType).isEmpty

        guard hasNoWalletsInChain || allowAdditional else {
            throw PrivyError(.embeddedWalletFailure(reason: .additionalWalletsBlocked))
        }

        // Imported wallets aren't HD primaries, so an imported-only user gets a primary wallet
        if auth.user.linkedAccounts.hasWalletOf(chainType: chainType) {
            return try await self.createAdditionalWallet(auth: auth, chainType: chainType, timeout: timeout)
        } else {
            return try await self.createPrimaryWallet(auth: auth, chainType: chainType, timeout: timeout)
        }
    }

    private func createPrimaryWallet(auth: InternalAuthSession, chainType: ChainType, timeout: Duration) async throws -> CreatedWallet {
        switch chainType {
        case .ethereum:
            let response = try await webViewHandler.createEthereumWallet(
                data: .init(
                    accessToken: auth.authToken,
                    solanaAddress: auth.user.linkedAccounts.getPrimaryEmbeddedSolanaWalletAccount()?.address
                ),
                timeout: timeout
            )

            return CreatedWallet(chainType: chainType, address: response.data.address)
        case .solana:
            let response = try await webViewHandler.createSolanaWallet(
                data: .init(
                    accessToken: auth.authToken,
                    ethereumAddress: auth.user.linkedAccounts.getPrimaryEmbeddedEthereumWalletAccount()?.address
                ),
                timeout: timeout
            )

            return CreatedWallet(chainType: chainType, address: response.data.publicKey)
        }
    }

    private func createAdditionalWallet(auth: InternalAuthSession, chainType: ChainType, timeout: Duration) async throws -> CreatedWallet {
        // Since we know user already has a wallet in this flow, there should definitely be a wallet for entropy info
        let entropyWalletInfo = try auth.user.linkedAccounts.getPrimaryWalletForEntropyInfo()
        let walletsOfChainType = auth.user.linkedAccounts.getEmbeddedWalletAccounts(chainType: chainType)

        let createAdditionalWalletRequestData = ChainAgnosticCreateAdditionalWalletRequestData(
            chainType: chainType,
            accessToken: auth.authToken,
            hdWalletIndex: walletsOfChainType.count,
            entropyWallet: entropyWalletInfo
        )

        let response = try await webViewHandler.createAdditionalWallet(data: createAdditionalWalletRequestData, timeout: timeout)
        return CreatedWallet(chainType: chainType, address: response.data.address)
    }
}
