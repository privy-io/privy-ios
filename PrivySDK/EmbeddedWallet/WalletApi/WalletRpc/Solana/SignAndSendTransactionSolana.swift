// signAndSendTransaction solana RPC

internal struct WalletApiSolanaSignAndSendTransactionRpcParams: Encodable {
    /// Transaction to sign with the wallet and broadcast. Must be base64 encoded.
    internal let transaction: String
    /// Encoding scheme for the transaction
    internal let encoding: TransactionEncoding = .base64

    internal enum TransactionEncoding: String, Encodable {
        case base64 = "base64"
    }
}

internal struct WalletApiSolanaSignAndSendTransactionRpcResponse: Decodable {
    /// Hash of the broadcasted transaction.
    internal let hash: String
}
