import Foundation

fileprivate enum RpcMethodName: String {
    case ethereumPersonalSign = "personal_sign"
    case ethereumSecp256k1Sign = "secp256k1_sign"
    case ethereumSignTransaction = "eth_signTransaction"
    case ethereumSendTransaction = "eth_sendTransaction"
    case ethereumSignTypedDataV4 = "eth_signTypedData_v4"
    case solanaSignMessage = "signMessage"
    case solanaSignTransaction = "signTransaction"
    case solanaSignAndSendTransaction = "signAndSendTransaction"
}

internal enum WalletApiRpcRequest: Encodable {
    case ethereumPersonalSign(WalletApiEthereumPersonalSignRpcParams)
    case ethereumSecp256k1Sign(WalletApiEthereumSecp256k1SignRpcParams)
    case ethereumSignTransaction(WalletApiEthereumSignTransactionRpcParams)
    case ethereumSendTransaction(WalletApiEthereumSendTransactionRpcParams, WalletApiCAIP2)
    case ethereumSignTypedDataV4(WalletApiEthereumSignTypedDataV4RpcParams)
    case solanaSignMessage(WalletApiSolanaSignMessageRpcParams)
    case solanaSignTransaction(WalletApiSolanaSignTransactionRpcParams)
    case solanaSignAndSendTransaction(WalletApiSolanaSignAndSendTransactionRpcParams, WalletApiCAIP2)

    private var method: String {
        switch self {
        case .ethereumPersonalSign:
            return RpcMethodName.ethereumPersonalSign.rawValue
        case .ethereumSecp256k1Sign:
            return RpcMethodName.ethereumSecp256k1Sign.rawValue
        case .ethereumSignTransaction:
            return RpcMethodName.ethereumSignTransaction.rawValue
        case .ethereumSendTransaction:
            return RpcMethodName.ethereumSendTransaction.rawValue
        case .ethereumSignTypedDataV4:
            return RpcMethodName.ethereumSignTypedDataV4.rawValue
        case .solanaSignMessage:
            return RpcMethodName.solanaSignMessage.rawValue
        case .solanaSignTransaction:
            return RpcMethodName.solanaSignTransaction.rawValue
        case .solanaSignAndSendTransaction:
            return RpcMethodName.solanaSignAndSendTransaction.rawValue
        }
    }

    private var params: any Encodable {
        switch self {
        case .ethereumPersonalSign(let params):
            return params
        case .ethereumSecp256k1Sign(let params):
            return params
        case .ethereumSignTransaction(let params):
            return params
        case .ethereumSendTransaction(let params, _):
            return params
        case .ethereumSignTypedDataV4(let params):
            return params
        case .solanaSignMessage(let params):
            return params
        case .solanaSignTransaction(let params):
            return params
        case .solanaSignAndSendTransaction(let params, _):
            return params
        }
    }

    private enum CodingKeys: String, CodingKey {
        case method
        case params
        case caip2
    }

    internal func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.method, forKey: .method)
        try container.encode(self.params, forKey: .params)
        if case .ethereumSendTransaction(_, let caip2) = self {
            try container.encode(caip2, forKey: .caip2)
        }
        if case .solanaSignAndSendTransaction(_, let caip2) = self {
            try container.encode(caip2, forKey: .caip2)
        }
    }
}

internal enum WalletApiRpcResponse: Decodable {
    case ethereumPersonalSign(WalletApiEthereumPersonalSignRpcResponse)
    case ethereumSecp256k1Sign(WalletApiEthereumSecp256k1SignRpcResponse)
    case ethereumSignTransaction(WalletApiEthereumSignTransactionRpcResponse)
    case ethereumSendTransaction(WalletApiEthereumSendTransactionRpcResponse)
    case ethereumSignTypedDataV4(WalletApiEthereumSignTypedDataV4RpcResponse)
    case solanaSignMessage(WalletApiSolanaSignMessageRpcResponse)
    case solanaSignTransaction(WalletApiSolanaSignTransactionRpcResponse)
    case solanaSignAndSendTransaction(WalletApiSolanaSignAndSendTransactionRpcResponse)

    private enum CodingKeys: String, CodingKey {
        case method
        case data
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let method = try container.decode(String.self, forKey: .method)

        switch method {
        case RpcMethodName.ethereumPersonalSign.rawValue:
            self = .ethereumPersonalSign(try container.decode(WalletApiEthereumPersonalSignRpcResponse.self, forKey: .data))
        case RpcMethodName.ethereumSecp256k1Sign.rawValue:
            self = .ethereumSecp256k1Sign(try container.decode(WalletApiEthereumSecp256k1SignRpcResponse.self, forKey: .data))
        case RpcMethodName.ethereumSignTransaction.rawValue:
            self = .ethereumSignTransaction(try container.decode(WalletApiEthereumSignTransactionRpcResponse.self, forKey: .data))
        case RpcMethodName.ethereumSendTransaction.rawValue:
            self = .ethereumSendTransaction(try container.decode(WalletApiEthereumSendTransactionRpcResponse.self, forKey: .data))
        case RpcMethodName.ethereumSignTypedDataV4.rawValue:
            self = .ethereumSignTypedDataV4(try container.decode(WalletApiEthereumSignTypedDataV4RpcResponse.self, forKey: .data))
        case RpcMethodName.solanaSignMessage.rawValue:
            self = .solanaSignMessage(try container.decode(WalletApiSolanaSignMessageRpcResponse.self, forKey: .data))
        case RpcMethodName.solanaSignTransaction.rawValue:
            self = .solanaSignTransaction(try container.decode(WalletApiSolanaSignTransactionRpcResponse.self, forKey: .data))
        case RpcMethodName.solanaSignAndSendTransaction.rawValue:
            self = .solanaSignAndSendTransaction(try container.decode(WalletApiSolanaSignAndSendTransactionRpcResponse.self, forKey: .data))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .method,
                in: container,
                debugDescription: "Unknown method: \(method)"
            )
        }
    }
}
