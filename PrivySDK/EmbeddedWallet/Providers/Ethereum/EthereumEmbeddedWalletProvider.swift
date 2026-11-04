import Foundation

/**
  An Ethereum wallet RPC provider, inspired by [EIP-1193 standard](https://eips.ethereum.org/EIPS/eip-1193).
 */
public protocol EmbeddedEthereumWalletProvider: Sendable {
    /// The currently set chain ID
    var chainId: Int { get async }

    /// The Ethereum provider RPC request. Example usage:
    /// - Parameters:
    ///     - request: The RPC request
    ///
    /// - Returns: The response data as a String
    ///
    /// - Throws: If wallet isn't connected, or if RPC request fails
    ///
    /// ```swift
    /// let request = RpcRequest(method: "personal_sign", params: ["This message is to be signed.", wallet.address])
    /// let signature = try await request(data)
    /// ```
    func request(_ request: EthereumRpcRequest) async throws -> String

    /// Specify the EVM chain's ID and rpcUrl
    /// - Parameters:
    /// - chainId: The chian's ID
    /// - rpcUrl: The RPC URL
    func switchChain(chainId: Int, rpcUrl: String?) async
}
