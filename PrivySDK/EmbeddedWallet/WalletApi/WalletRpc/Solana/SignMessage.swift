// signMessage solana RPC

internal struct WalletApiSolanaSignMessageRpcParams: Encodable {
    /// Message to sign with the wallet. Must be base64 encoded.
    internal let message: String
    /// Encoding scheme for the message
    internal let encoding: MessageEncoding = .base64

    internal enum MessageEncoding: String, Encodable {
        case base64 = "base64"
    }
}

internal struct WalletApiSolanaSignMessageRpcResponse: Decodable {
    /// Signature produced by the wallet, base64 encoded.
    internal let signature: String
}
