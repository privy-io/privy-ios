import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var embeddedEthereumWalletProvider: ParameterFactory<EmbeddedWalletAccount, EmbeddedEthereumWalletProvider> {
        self { EmbeddedEthereumWalletProviderImpl(account: $0) }.unique
    }
}

private actor EmbeddedEthereumWalletProviderImpl: EmbeddedEthereumWalletProvider {
    private let config: PrivyConfig = resolve(\PrivyContainer.config)
    private let targetWalletAddress: String
    private let rpcExecutor: EmbeddedWalletRPCExecutor

    // Actor isolated properties
    var rpcUrl: String?
    var chainId: Int

    init(account: EmbeddedWalletAccount) {
        self.chainId = 1
        self.rpcUrl = nil
        self.targetWalletAddress = account.address
        self.rpcExecutor = PrivyContainer.shared.embeddedWalletRpcExecutor(account)
    }

    // This is the preferred way for developers to make an RPC request, which returns the String data directly
    func request(_ request: EthereumRpcRequest) async throws -> String {
        return try await handleRpcRequest(request).response.data
    }

    func switchChain(chainId: Int, rpcUrl: String? = nil) async {
        self.chainId = chainId
        self.rpcUrl = rpcUrl
    }

    func handleRpcRequest(_ request: EthereumRpcRequest) async throws -> WalletRpcResponseData {
        switch request.method {
        case
            // Privy iFrame Ethereum supported methods
            "eth_sign",
            "secp256k1_sign",
            "personal_sign",
            "eth_populateTransactionRequest",
            "eth_signTypedData_v4",
            "eth_signTransaction",
            "eth_sendTransaction":
            let response = try await sendEthereumWalletRpc(request)
            return response

        default:
            return try await self.handleJsonRpc(request)
        }
    }

    func sendEthereumWalletRpc(_ request: EthereumRpcRequest) async throws -> WalletRpcResponseData {
        return try await rpcExecutor.perform(
            request: EthereumWalletRpcRequest(
                method: request.method,
                params: request.params,
                chainId: self.chainId
            )
        )
    }

    func handleJsonRpc(_ rpcRequest: EthereumRpcRequest) async throws -> WalletRpcResponseData {
        let endpoint = try getJsonRpcEndpoint()

        guard let url = URL(string: endpoint) else {
            throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "method": rpcRequest.method,
            "params": rpcRequest.params,
            "id": "1",
            "jsonrpc": "2.0",
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
        }

        guard let responseJsonString = String(data: data, encoding: .utf8) else {
            throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
        }

        return .init(
            address: self.targetWalletAddress,
            response: .init(
                method: rpcRequest.method,
                data: responseJsonString
            )
        )
    }

    func getJsonRpcEndpoint() throws -> String {
        if let custom = self.rpcUrl {
            return custom
        }

        guard let chain = SupportedChain.allCases.first(where: { $0.chainInfo.id == self.chainId }) else {
            throw PrivyError(.embeddedWalletFailure(reason: .unsupportedChain))
        }

        // Prefer the Privy endpoint and fall back to the chain's public endpoint.
        if let privyUrl = chain.chainInfo.rpcUrls.privy?.http.first {
            return "\(privyUrl)/?privyAppId=\(self.config.appId)"
        } else if let url = chain.chainInfo.rpcUrls.default.http.first {
            return url
        }

        throw PrivyError(.embeddedWalletFailure(reason: .rpcUrlNotFound))
    }
}
