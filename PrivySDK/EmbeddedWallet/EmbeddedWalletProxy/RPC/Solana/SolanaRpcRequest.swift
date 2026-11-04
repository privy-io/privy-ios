// Base Solana RPC request structure
internal enum SolanaRpcRequest: WalletRpcRequestBody {
    case signMessage(params: SolanaSignMessageParams)
    case signTransaction(params: SolanaSignTransactionParams)
    case signAndSendTransaction(params: SolanaSignAndSendTransactionParams)

    private enum CodingKeys: CodingKey {
        case method
        case params
    }

    internal var method: String {
        switch self {
        case .signMessage:
            return "signMessage"
        case .signTransaction:
            return "signTransaction"
        case .signAndSendTransaction:
            return "signAndSendTransaction"
        }
    }

    internal var params: any Encodable {
        switch self {
        case .signMessage(let params):
            return params
        case .signTransaction(let params):
            return params
        case .signAndSendTransaction(let params):
            return params
        }
    }

    internal func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.method, forKey: .method)
        try container.encode(self.params, forKey: .params)
    }
}

internal struct SolanaSignMessageParams: Encodable, Sendable {
    internal let message: String
}

internal struct SolanaSignTransactionParams: Encodable, Sendable {
    internal let transaction: String
}

internal struct SolanaSignAndSendTransactionParams: Encodable, Sendable {
    internal let transaction: String
    internal let caip2: WalletApiCAIP2
    internal let rpcUrl: String
    internal let options: SolanaSendOptions?

    private enum CodingKeys: CodingKey {
        case transaction
        case caip2
        // rpcUrl is omitted
        // options is omitted
    }
}
