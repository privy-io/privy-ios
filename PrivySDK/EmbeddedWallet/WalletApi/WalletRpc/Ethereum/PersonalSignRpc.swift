// personal_sign ethereum RPC

internal struct WalletApiEthereumPersonalSignRpcParams: Encodable {
    /// Message to sign with the wallet. Must be encoded per the scheme in `encoding`
    internal let message: String
    /// Encoding scheme for the message
    internal let encoding: MessageEncoding

    internal enum MessageEncoding: String, Encodable {
        /// Used for plaintext message signatures
        case utf8 = "utf-8"
        /// Used for signing raw bytes
        case hex = "hex"
    }
}

internal struct WalletApiEthereumPersonalSignRpcResponse: Decodable {
    /// Signature produced by the wallet
    internal let signature: String
}
