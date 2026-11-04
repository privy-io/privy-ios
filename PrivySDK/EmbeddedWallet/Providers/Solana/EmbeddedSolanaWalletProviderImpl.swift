import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var embeddedSolanaWalletProvider: ParameterFactory<EmbeddedWalletAccount, EmbeddedSolanaWalletProvider> {
        self { EmbeddedSolanaWalletProviderImpl(account: $0) }.unique
    }
}

private final class EmbeddedSolanaWalletProviderImpl: EmbeddedSolanaWalletProvider {
    private let targetWalletAddress: String
    private let rpcExecutor: EmbeddedWalletRPCExecutor

    init(account: EmbeddedWalletAccount) {
        self.targetWalletAddress = account.address
        self.rpcExecutor = PrivyContainer.shared.embeddedWalletRpcExecutor(account)
    }

    func signMessage(message: String) async throws -> String {
        let signMessageResponse = try await rpcExecutor.perform(
            request: SolanaRpcRequest.signMessage(
                params: SolanaSignMessageParams(message: message)
            )
        )

        return signMessageResponse.response.data
    }

    func signTransaction(transaction: Data) async throws -> String {
        let transactionBase64 = transaction.base64EncodedString()
        let signTransactionResponse = try await rpcExecutor.perform(
            request: SolanaRpcRequest.signTransaction(
                params: SolanaSignTransactionParams(transaction: transactionBase64)
            )
        )

        return signTransactionResponse.response.data
    }

    func signAndSendTransaction(transaction: Data, cluster: SolanaCluster, options: SolanaSendOptions?) async throws -> String {
        guard let caip2 = WalletApiCAIP2(string: cluster.caip2) else {
            throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: "signAndSendTransaction", desription: "The provided caip2 is invalid.")))
        }

        let transactionBase64 = transaction.base64EncodedString()
        let signAndSendTransactionResponse = try await rpcExecutor.perform(
            request: SolanaRpcRequest.signAndSendTransaction(
                params: SolanaSignAndSendTransactionParams(transaction: transactionBase64, caip2: caip2, rpcUrl: cluster.rpcUrl, options: options)
            )
        )

        return signAndSendTransactionResponse.response.data
    }
}
