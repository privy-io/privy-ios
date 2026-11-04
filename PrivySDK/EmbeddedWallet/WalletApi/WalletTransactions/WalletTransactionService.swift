import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var walletTransactionService: Factory<WalletTransactionService> {
        self { WalletTransactionServiceImpl() }.shared
    }
}

internal protocol WalletTransactionService: Sendable {
    /// Fetches paginated transaction history for a wallet.
    ///
    /// - Parameters:
    ///   - wallet: The embedded wallet to fetch transactions for.
    ///   - params: Query parameters including chain, asset/token filter, limit, and cursor.
    ///
    /// - Returns: A page of transactions with an optional cursor for the next page.
    /// - Throws: ``PrivyError`` if the wallet is not a TEE wallet or the API call fails.
    func getTransactions(for wallet: EmbeddedWallet, params: GetTransactionsParams) async throws -> TransactionsPage
}

private final class WalletTransactionServiceImpl: WalletTransactionService {
    private let walletApi: WalletApiRepository = resolve(\PrivyContainer.walletApiRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    internal func getTransactions(for wallet: EmbeddedWallet, params: GetTransactionsParams) async throws -> TransactionsPage {
        let walletType = wallet.chainType.rawValue.capitalized
        logger.debug("getTransactions called on \(walletType) wallet \(wallet.address)")

        guard wallet.isTEEWallet else {
            logger.error("getTransactions failed: wallet \(wallet.address) is not a TEE wallet", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .transactionError(message: "getTransactions requires a TEE wallet.")))
        }

        guard let walletId = wallet.id else {
            logger.error("getTransactions failed: wallet \(wallet.address) has no ID", error: nil)
            throw PrivyError(.embeddedWalletFailure(reason: .transactionError(message: "getTransactions requires a wallet with an ID.")))
        }

        logger.info("Fetching transactions for wallet \(walletId) on chain \(params.chain.queryValue)")

        do {
            let auth = try await authManager.refreshSessionIfNeeded()
            let token = auth.authToken

            let response = try await walletApi.getTransactions(walletId: walletId, params: params, token: token)
            let page = mapToTransactionsPage(response)

            logger.info("Successfully fetched \(page.transactions.count) transaction(s) for wallet \(walletId)")
            return page
        } catch let error as PrivyError {
            logger.error("getTransactions failed for \(walletType) wallet \(walletId)", error: error)
            throw error
        } catch {
            logger.error("getTransactions failed for \(walletType) wallet \(walletId)", error: error)
            throw PrivyError(.embeddedWalletFailure(reason: .transactionError(message: "Failed to fetch transactions: \(error.localizedDescription)")))
        }
    }

    private func mapToTransactionsPage(_ response: WalletTransactionsResponse) -> TransactionsPage {
        let transactions = response.transactions.map { tx in
            WalletTransaction(
                caip2: tx.caip2,
                transactionHash: tx.transactionHash,
                userOperationHash: tx.userOperationHash,
                status: mapStatus(tx.status),
                createdAt: tx.createdAt,
                sponsored: tx.sponsored,
                privyTransactionId: tx.privyTransactionId,
                walletId: tx.walletId,
                details: tx.details.map(mapDetails)
            )
        }
        return TransactionsPage(transactions: transactions, nextCursor: response.nextCursor)
    }

    private func mapStatus(_ status: String) -> TransactionStatus {
        switch status {
        case "broadcasted": .broadcasted
        case "confirmed": .confirmed
        case "execution_reverted": .executionReverted
        case "failed": .failed
        case "replaced": .replaced
        case "finalized": .finalized
        case "provider_error": .providerError
        case "pending": .pending
        default: .unknown(status)
        }
    }

    private func mapDetails(_ details: TransactionDetailsApiModel) -> TransactionDetails {
        TransactionDetails(
            type: mapType(details.type),
            sender: details.sender,
            senderPrivyUserId: details.senderPrivyUserId,
            recipient: details.recipient,
            recipientPrivyUserId: details.recipientPrivyUserId,
            chain: details.chain,
            asset: details.asset,
            rawValue: details.rawValue,
            rawValueDecimals: details.rawValueDecimals,
            displayValues: details.displayValues
        )
    }

    private func mapType(_ type: String) -> TransactionType {
        switch type {
        case "transfer_sent": .transferSent
        case "transfer_received": .transferReceived
        default: .unknown(type)
        }
    }
}
