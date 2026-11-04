import Foundation
internal import FactoryKit

internal struct EmbeddedEthereumWalletImpl: EmbeddedEthereumWallet {
    internal let id: String?
    internal let imported: Bool
    internal let userCanSign: Bool
    internal let address: String
    internal let recoveryMethod: String?
    internal let hdWalletIndex: Int
    internal let provider: EmbeddedEthereumWalletProvider

    private let walletSignerService: WalletSignerService
    private let walletTransactionService: WalletTransactionService

    internal init(
        id: String?,
        imported: Bool,
        userCanSign: Bool,
        address: String,
        recoveryMethod: String?,
        hdWalletIndex: Int,
        provider: EmbeddedEthereumWalletProvider,
        walletSignerService: WalletSignerService,
        walletTransactionService: WalletTransactionService
    ) {
        self.id = id
        self.imported = imported
        self.userCanSign = userCanSign
        self.address = address
        self.recoveryMethod = recoveryMethod
        self.hdWalletIndex = hdWalletIndex
        self.provider = provider
        self.walletSignerService = walletSignerService
        self.walletTransactionService = walletTransactionService
    }

    internal func addSigners(_ signers: [SignerInput]) async throws {
        try await walletSignerService.addSigners(to: self, signers: signers)
    }

    internal func removeSigner(signerId: String) async throws {
        try await walletSignerService.removeSigner(from: self, signerId: signerId)
    }

    internal func removeAllSigners() async throws {
        try await walletSignerService.removeAllSigners(from: self)
    }

    internal func getTransactions(_ params: GetTransactionsParams) async throws -> TransactionsPage {
        try await walletTransactionService.getTransactions(for: self, params: params)
    }
}
