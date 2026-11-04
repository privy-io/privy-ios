import Foundation

/// Request made on behalf of the embedded wallet for the logged in user
public struct EthereumRpcRequest: Sendable {
    /**
      Ethereum JSON RPC method, reference can be found in the [JSON RPC API ](https://ethereum.org/en/developers/docs/apis/json-rpc/).

      Supported methods:

      * eth_accounts
      * personal_sign
      * secp256k1_sign
      * eth_sign
      * eth_signTypedData_v4
      * eth_signTransaction
      * eth_sendTransaction
      * eth_sendRawTransaction
      * personal_sign
      * eth_chainId
     */
    public let method: String

    /// Ethereum JSON RPC method params, param reference for each method can be found in the [JSON RPC API ](https://ethereum.org/en/developers/docs/apis/json-rpc/).
    public let params: [String]

    /// Define the method and parameters for an ethereum RPC request
    public init(method: String, params: [String]) {
        self.method = method
        self.params = params
    }

    public static func personalSign(message: String, address: String) -> EthereumRpcRequest {
        .init(method: "personal_sign", params: [message, address])
    }

    public static func secp256k1Sign(hash: String) -> EthereumRpcRequest {
        .init(method: "secp256k1_sign", params: [hash])
    }

    public static func ethSign(address: String, message: String) -> EthereumRpcRequest {
        .init(method: "eth_sign", params: [address, message])
    }

    public static func ethSignTypedDataV4(address: String, typedData: EIP712TypedData) throws -> EthereumRpcRequest {
        let encodedTypedData = try JSONEncoder().encode(typedData)
        guard let typedDataJsonString = String(data: encodedTypedData, encoding: .utf8) else {
            // Should not happen given JSONEncoder encodes as a utf8 string
            throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: "eth_signTypedData_v4", desription: "Failed to encode the provided typed data")))
        }
        return .init(method: "eth_signTypedData_v4", params: [address, typedDataJsonString])
    }

    public static func ethSignTransaction(transaction: UnsignedEthTransaction) throws -> EthereumRpcRequest {
        let encodedTransaction = try JSONEncoder().encode(transaction)
        guard let transactionJsonString = String(data: encodedTransaction, encoding: .utf8) else {
            // Should not happen given JSONEncoder encodes as a utf8 string
            throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: "eth_signTransaction", desription: "Failed to encode the provided transaction")))
        }
        return .init(method: "eth_signTransaction", params: [transactionJsonString])
    }

    public static func ethSendTransaction(transaction: UnsignedEthTransaction) throws -> EthereumRpcRequest {
        let encodedTransaction = try JSONEncoder().encode(transaction)
        guard let transactionJsonString = String(data: encodedTransaction, encoding: .utf8) else {
            // Should not happen given JSONEncoder encodes as a utf8 string
            throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: "eth_sendTransaction", desription: "Failed to encode the provided transaction")))
        }
        return .init(method: "eth_sendTransaction", params: [transactionJsonString])
    }
}
