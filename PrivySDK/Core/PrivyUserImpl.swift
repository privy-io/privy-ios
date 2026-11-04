import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var privyUser: Factory<PrivyUser> {
        self { PrivyUserImpl() }.unique
    }
}

private final class PrivyUserImpl: PrivyUser, CustomStringConvertible, Sendable {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let embeddedWalletManager: EmbeddedWalletManager = resolve(\PrivyContainer.embeddedWalletManager)
    private let caidRepository: ClientAnalyticsIdRepository = resolve(\PrivyContainer.caidRepository)
    private let userSigner: UserSigner = resolve(\PrivyContainer.userSigner)
    private let walletSignerService: WalletSignerService = resolve(\PrivyContainer.walletSignerService)
    private let walletTransactionService: WalletTransactionService = resolve(\PrivyContainer.walletTransactionService)
    private let walletImportService: WalletImportService = resolve(\PrivyContainer.walletImportService)
    private let userSignerRepository: UserSignerRepository = resolve(\PrivyContainer.userSignerRepository)
    public let mfa: PrivyUserMfa = resolve(\PrivyContainer.privyUserMfa)

    var id: String {
        guard let session = try? authManager.ensureAuthenticated() else { return "" }
        return session.user.id
    }

    var identityToken: String? {
        guard let session = try? authManager.ensureAuthenticated() else { return nil }
        return session.identityToken
    }

    var createdAt: Date? {
        guard let session = try? authManager.ensureAuthenticated() else { return nil }
        return session.user.createdAt
    }

    var linkedAccounts: [LinkedAccount] {
        guard let session = try? authManager.ensureAuthenticated() else { return [] }
        return session.user.linkedAccounts
    }

    var mfaMethods: [MfaMethod] {
        guard let session = try? authManager.ensureAuthenticated() else { return [] }
        return session.user.mfaMethods
    }

    var embeddedEthereumWallets: [EmbeddedEthereumWallet] {
        return self.linkedAccounts
            .compactMap { account in
                guard case .embeddedEthereumWallet(let ethWalletAccount) = account else { return nil }
                return ethWalletAccount
            }.map { (wallet: EmbeddedEthereumWalletAccount) in
                EmbeddedEthereumWalletImpl(
                    id: wallet.id,
                    imported: wallet.imported,
                    userCanSign: wallet.userCanSign,
                    address: wallet.address,
                    recoveryMethod: wallet.recoveryMethod,
                    hdWalletIndex: wallet.hdWalletIndex,
                    provider: PrivyContainer.shared.embeddedEthereumWalletProvider(wallet),
                    walletSignerService: walletSignerService,
                    walletTransactionService: walletTransactionService
                )
            }
    }

    var embeddedSolanaWallets: [EmbeddedSolanaWallet] {
        return self.linkedAccounts
            .compactMap { account in
                guard case .embeddedSolanaWallet(let solWalletAccount) = account else { return nil }
                return solWalletAccount
            }.map { (wallet: EmbeddedSolanaWalletAccount) in
                EmbeddedSolanaWalletImpl(
                    id: wallet.id,
                    imported: wallet.imported,
                    userCanSign: wallet.userCanSign,
                    address: wallet.address,
                    recoveryMethod: wallet.recoveryMethod,
                    hdWalletIndex: wallet.hdWalletIndex,
                    provider: PrivyContainer.shared.embeddedSolanaWalletProvider(wallet),
                    walletSignerService: walletSignerService,
                    walletTransactionService: walletTransactionService
                )
            }
    }

    var description: String {
        return """
        Privy user:

        ID: \(id)

        Identity token: \(identityToken ?? "N/A")

        Linked Accounts:
        \(linkedAccounts)
        """
    }

    func getAccessToken() async throws -> String {
        // refreshSessionIfNeeded handles authentication check
        let authSession = try await authManager.refreshSessionIfNeeded()
        return authSession.authToken
    }

    func createEthereumWallet(allowAdditional: Bool, timeout: Duration) async throws -> any EmbeddedEthereumWallet {
        let wallet = try await embeddedWalletManager.createWallet(chainType: .ethereum, allowAdditional: allowAdditional, timeout: timeout)

        return EmbeddedEthereumWalletImpl(
            id: wallet.id,
            imported: wallet.imported,
            userCanSign: wallet.userCanSign,
            address: wallet.address,
            recoveryMethod: wallet.recoveryMethod,
            hdWalletIndex: wallet.hdWalletIndex,
            provider: PrivyContainer.shared.embeddedEthereumWalletProvider(wallet),
            walletSignerService: walletSignerService,
            walletTransactionService: walletTransactionService
        )
    }

    func createSolanaWallet(allowAdditional: Bool, timeout: Duration) async throws -> any EmbeddedSolanaWallet {
        let wallet = try await embeddedWalletManager.createWallet(chainType: .solana, allowAdditional: allowAdditional, timeout: timeout)

        return EmbeddedSolanaWalletImpl(
            id: wallet.id,
            imported: wallet.imported,
            userCanSign: wallet.userCanSign,
            address: wallet.address,
            recoveryMethod: wallet.recoveryMethod,
            hdWalletIndex: wallet.hdWalletIndex,
            provider: PrivyContainer.shared.embeddedSolanaWalletProvider(wallet),
            walletSignerService: walletSignerService,
            walletTransactionService: walletTransactionService
        )
    }

    func importWallet(
        chainType: WalletImportSupportedChainType,
        address: String,
        secret: WalletImportSecret
    ) async throws -> any EmbeddedWallet {
        let wallet = try await walletImportService.importWallet(secret, chainType: chainType, address: address)

        return switch chainType {
        case .ethereum:
            EmbeddedEthereumWalletImpl(
                id: wallet.id,
                imported: wallet.imported,
                userCanSign: wallet.userCanSign,
                address: wallet.address,
                recoveryMethod: wallet.recoveryMethod,
                hdWalletIndex: wallet.hdWalletIndex,
                provider: PrivyContainer.shared.embeddedEthereumWalletProvider(wallet),
                walletSignerService: walletSignerService,
                walletTransactionService: walletTransactionService
            )
        case .solana:
            EmbeddedSolanaWalletImpl(
                id: wallet.id,
                imported: wallet.imported,
                userCanSign: wallet.userCanSign,
                address: wallet.address,
                recoveryMethod: wallet.recoveryMethod,
                hdWalletIndex: wallet.hdWalletIndex,
                provider: PrivyContainer.shared.embeddedSolanaWalletProvider(wallet),
                walletSignerService: walletSignerService,
                walletTransactionService: walletTransactionService
            )
        }
    }

    func refresh() async throws {
        // Drop result type because we're not returning the user on refresh
        let _ = try await authManager.refreshUser()
        return
    }

    func migrateWalletsIfNeeded() async throws {
        let migrationManager = resolve(\PrivyContainer.walletMigrationManager)
        try await migrationManager.migrateWalletsIfNeeded()
    }

    func logout() {
        Task {
            await logout()
        }
    }

    func logout() async {
        await authManager.logout()
        await embeddedWalletManager.logout()
        await userSignerRepository.clearUserSigner()
        await caidRepository.resetClientId()
    }

    func generateAuthorizationSignature<T: Encodable>(
        payload: WalletApiPayload<T>
    ) async throws -> String {
        return try await userSigner.signature(for: payload)
    }

    func generateAuthorizationSignature(
        payload: Data
    ) async throws -> String {
        return try await userSigner.signature(for: payload)
    }
}
