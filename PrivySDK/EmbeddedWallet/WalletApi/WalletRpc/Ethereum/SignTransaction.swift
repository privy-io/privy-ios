// eth_signTransaction ethereum RPC

internal struct WalletApiEthereumSignTransactionRpcParams: Encodable {
    /// The bytes to sign with the wallet. Must be a hex encoding (0x...)
    internal let transaction: WalletApiUnsignedEthereumTransaction
}

internal struct WalletApiEthereumSignTransactionRpcResponse: Decodable {
    /// Signature produced by the wallet
    internal let signed_transaction: String
}
