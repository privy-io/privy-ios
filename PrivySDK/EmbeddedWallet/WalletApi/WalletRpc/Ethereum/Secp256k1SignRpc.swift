// secp256pk1_sign ethereum RPC

internal struct WalletApiEthereumSecp256k1SignRpcParams: Encodable {
    /// The bytes to sign with the wallet. Must be a hex encoding (0x...)
    internal let hash: String
}

internal struct WalletApiEthereumSecp256k1SignRpcResponse: Decodable {
    /// Signature produced by the wallet
    internal let signature: String
}
