// signTransaction solana RPC

internal struct WalletApiSolanaSignTransactionRpcParams: Encodable {
    /// Transaction to sign with the wallet. Must be base64 encoded.
    internal let transaction: String
    /// Encoding scheme for the transaction
    internal let encoding: TransactionEncoding = .base64

    internal enum TransactionEncoding: String, Encodable {
        case base64 = "base64"
    }
}

internal struct WalletApiSolanaSignTransactionRpcResponse: Decodable {
    /// Signed transaction produced by the wallet, RLP encoded.
    internal let signed_transaction: String
    /// Encoding scheme for the transaction
    internal let encoding: TransactionEncoding

    internal enum TransactionEncoding: String, Decodable {
        case base64 = "base64"
    }
}
