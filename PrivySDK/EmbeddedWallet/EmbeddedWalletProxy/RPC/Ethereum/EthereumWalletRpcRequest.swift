// Base Ethereum RPC request structure
internal struct EthereumWalletRpcRequest: WalletRpcRequestBody {
    internal let method: String
    internal let params: [String]
    internal let chainId: Int
}
