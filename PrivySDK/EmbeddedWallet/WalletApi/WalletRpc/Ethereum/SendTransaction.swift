// eth_sendTransaction ethereum RPC

internal struct WalletApiEthereumSendTransactionRpcParams: Encodable {
    /// The transaction to be signed with the wallet and broadcast.
    internal let transaction: WalletApiUnsignedEthereumTransaction
}

internal struct WalletApiEthereumSendTransactionRpcResponse: Decodable {
    /// A Privy-assigned id for the sent transaction.
    internal let transaction_id: String
    /// Blockchain hash of the sent transaction.
    internal let hash: String
    /// The CAIP-2 chain id the transaction was sent on.
    internal let caip2: WalletApiCAIP2
}
