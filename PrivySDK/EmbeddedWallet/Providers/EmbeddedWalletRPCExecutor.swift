import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var embeddedWalletRpcExecutor: ParameterFactory<EmbeddedWalletAccount, EmbeddedWalletRPCExecutor> {
        self {
            if ($0.isTEEWallet) {
                WalletApiRPCExecutor(account: $0)
            } else {
                WebViewWalletRPCExecutor(account: $0)
            }
        }.unique
    }
}

/// A strategy for running an RPC on an embedded wallet.
/// The protocol can be used to run an RPC request without referencing the specifics on how the request is performed.
internal protocol EmbeddedWalletRPCExecutor: Sendable {
    /// Perform an RPC request in the associated embedded wallet, getting back a response
    func perform<Request: WalletRpcRequestBody>(request: Request) async throws -> WalletRpcResponseData
}

/// An RPC execution strategy for server wallets, via the Wallets API
private final class WalletApiRPCExecutor: EmbeddedWalletRPCExecutor {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let walletApi: WalletApiRepository = resolve(\PrivyContainer.walletApiRepository)

    private let account: EmbeddedWalletAccount

    init(account: EmbeddedWalletAccount) {
        self.account = account
    }

    internal func perform<Request: WalletRpcRequestBody>(request: Request) async throws -> WalletRpcResponseData {
        let auth = try await authManager.refreshSessionIfNeeded()

        guard account.isTEEWallet, let walletId = account.id else {
            // This should never happen, as we construct the class for TEE wallets only.
            throw PrivyError(.embeddedWalletFailure(reason: .unsupportedRPC(rpcMethod: request.method)))
        }

        switch account.chainType {
        case .ethereum:
            // EmbeddedEthereumWalletProviderImpl always passes in this type
            guard let request = request as? EthereumWalletRpcRequest else {
                // An unexpected error
                throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
            }

            switch request.method {
            case "personal_sign":
                guard let message = request.params.first else {
                    throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: request.method, desription: "The params array should contain the message to sign in its first position")))
                }
                let params: WalletApiEthereumPersonalSignRpcParams = message.isHexEncoded ? .init(message: String(message.dropFirst(2)), encoding: .hex) : .init(message: message, encoding: .utf8)

                let response = try await walletApi.rpc(.ethereumPersonalSign(params), walletId: walletId, token: auth.authToken)

                guard case let .ethereumPersonalSign(personalSignRpcResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                return WalletRpcResponseData(address: account.address, response: .init(method: request.method, data: personalSignRpcResponse.signature))
            case "secp256k1_sign":
                guard let hash = request.params.first, hash.isHexEncoded else {
                    throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: request.method, desription: "The params array should contain a hex encoded hash to sign in its first position")))
                }
                let params = WalletApiEthereumSecp256k1SignRpcParams(hash: hash)

                let response = try await walletApi.rpc(.ethereumSecp256k1Sign(params), walletId: walletId, token: auth.authToken)

                guard case let .ethereumSecp256k1Sign(secp256k1SignRpcResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                return WalletRpcResponseData(address: account.address, response: .init(method: request.method, data: secp256k1SignRpcResponse.signature))
            case "eth_sign":
                guard request.params.count == 2 else {
                    throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: request.method, desription: "The params array should be [address, message]")))
                }

                let message = request.params[1]

                guard message.isHexEncoded else {
                    throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: request.method, desription: "The message to sign should be a valid hex encoding")))
                }

                let params = WalletApiEthereumSecp256k1SignRpcParams(hash: message)

                let response = try await walletApi.rpc(.ethereumSecp256k1Sign(params), walletId: walletId, token: auth.authToken)

                guard case let .ethereumSecp256k1Sign(secp256k1SignRpcResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                return WalletRpcResponseData(address: account.address, response: .init(method: request.method, data: secp256k1SignRpcResponse.signature))
            case "eth_signTypedData_v4":
                guard request.params.count == 2 else {
                    throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: request.method, desription: "The params array should be [address, typedData]")))
                }

                let typedDataJsonString = request.params[1]

                let typedData = try JSONDecoder().decode(
                    WalletApiEthereumSignTypedDataV4RpcParams.EthereumTypedDataV4.self,
                    from: typedDataJsonString.data(using: .utf8)!
                )

                let params = WalletApiEthereumSignTypedDataV4RpcParams(typedData: typedData)

                let response = try await walletApi.rpc(.ethereumSignTypedDataV4(params), walletId: walletId, token: auth.authToken)

                guard case let .ethereumSignTypedDataV4(signTypedDataV4RpcResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                return WalletRpcResponseData(address: account.address, response: .init(method: request.method, data: signTypedDataV4RpcResponse.signature))
            case "eth_signTransaction":
                guard request.params.count == 1, let txJsonString = request.params.first else {
                    throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: request.method, desription: "The params array should contain the transaction to sign in its first position")))
                }

                let transaction = try JSONDecoder().decode(UnsignedEthereumTransaction.self, from: txJsonString.data(using: .utf8)!)

                let response = try await walletApi.rpc(.ethereumSignTransaction(.init(transaction: transaction.toWalletApi())), walletId: walletId, token: auth.authToken)

                guard case let .ethereumSignTransaction(signTransactionRpcResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                return WalletRpcResponseData(address: account.address, response: .init(method: request.method, data: signTransactionRpcResponse.signed_transaction))
            case "eth_sendTransaction":
                guard request.params.count == 1, let txJsonString = request.params.first else {
                    throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: request.method, desription: "The params array should contain the transaction to send in its first position")))
                }

                let transaction = try JSONDecoder().decode(UnsignedEthereumTransaction.self, from: txJsonString.data(using: .utf8)!)

                let params = WalletApiEthereumSendTransactionRpcParams(transaction: transaction.toWalletApi())
                let caip2 = WalletApiCAIP2(eip155: transaction.chainId?.number ?? request.chainId)
                let rpcRequest: WalletApiRpcRequest = .ethereumSendTransaction(params, caip2)

                let response = try await walletApi.rpc(rpcRequest, walletId: walletId, token: auth.authToken)

                guard case let .ethereumSendTransaction(sendTransactionRpcResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                return WalletRpcResponseData(address: account.address, response: .init(method: request.method, data: sendTransactionRpcResponse.hash))
            case "eth_populateTransactionRequest":
                // eth_populateTransactionRequest is explicitly not supported under the TEE stack.
                // Decision made by the team based on low usage, we can revisit if demand for this is high,
                // possibly by handling at the SDK level
                throw PrivyError(.embeddedWalletFailure(reason: .unsupportedRPC(rpcMethod: request.method)))
            default:
                throw PrivyError(.embeddedWalletFailure(reason: .unsupportedRPC(rpcMethod: request.method)))
            }
        case .solana:
            // EmbeddedSolanaWalletProviderImpl always passes in this type
            guard let request = request as? SolanaRpcRequest else {
                // An unexpected error
                throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
            }

            switch request {
            case .signMessage(let params):
                let params = WalletApiSolanaSignMessageRpcParams(message: params.message)

                let response = try await walletApi.rpc(.solanaSignMessage(params), walletId: walletId, token: auth.authToken)

                guard case let .solanaSignMessage(signMessageResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                return WalletRpcResponseData(
                    address: account.address,
                    response: .init(method: request.method, data: signMessageResponse.signature)
                )
            case .signTransaction(let params):
                let params = WalletApiSolanaSignTransactionRpcParams(transaction: params.transaction)

                let response = try await walletApi.rpc(.solanaSignTransaction(params), walletId: walletId, token: auth.authToken)

                guard case let .solanaSignTransaction(signTransactionResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                return WalletRpcResponseData(
                    address: account.address,
                    response: .init(method: request.method, data: signTransactionResponse.signed_transaction)
                )
            case let .signAndSendTransaction(params):
                let caip2 = params.caip2
                let params = WalletApiSolanaSignAndSendTransactionRpcParams(transaction: params.transaction)

                let response = try await walletApi.rpc(.solanaSignAndSendTransaction(params, caip2), walletId: walletId, token: auth.authToken)

                guard case let .solanaSignAndSendTransaction(signAndSendTransactionResponse) = response else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }
                return WalletRpcResponseData(address: account.address, response: .init(method: request.method, data: signAndSendTransactionResponse.hash))
            }
        }
    }
}

/// An RPC execution strategy for on-device embedded wallets, via the WebView
private final class WebViewWalletRPCExecutor: EmbeddedWalletRPCExecutor {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let handler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)
    private let config: PrivyConfig = resolve(\PrivyContainer.config)
    private let walletConnector: WebViewWalletConnector = resolve(\PrivyContainer.webViewWalletConnector)

    internal let account: EmbeddedWalletAccount

    internal init(account: EmbeddedWalletAccount) {
        self.account = account
    }

    internal func perform<Request: WalletRpcRequestBody>(request: Request) async throws -> WalletRpcResponseData {
        let auth = try await authManager.refreshSessionIfNeeded()

        let primaryWallet = try auth.user.linkedAccounts.getPrimaryWalletForEntropyInfo()

        guard let targetWallet = await getEmbeddedWalletWithAddress(self.account.address) else {
            // If specific wallet with address was requested, but it was not found, throw error
            throw PrivyError(.embeddedWalletFailure(reason: .noWalletAvailable))
        }

        // Some Solana RPCs are implemented client-side for webview execution
        if let solanaRequest = request as? SolanaRpcRequest {
            if case let .signTransaction(params) = solanaRequest {
                guard let txBytes = Data(base64Encoded: params.transaction) else {
                    throw PrivyError(.embeddedWalletFailure(reason: .invalidRpcParams(method: solanaRequest.method, desription: "The transaction to sign should be a valid base64 encoding")))
                }
                let transaction = try SolanaTransaction(bytes: txBytes)

                let message = transaction.message.base64EncodedString()
                let response = try await self.perform(
                    request: SolanaRpcRequest.signMessage(
                        params: SolanaSignMessageParams(message: message)
                    )
                )
                let signature = response.response.data
                guard let signatureBytes = Data(base64Encoded: signature) else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                let signedTx = try transaction.add(signature: signatureBytes)
                let signedTxBase64 = signedTx.base64EncodedString()
                return .init(address: account.address, response: .init(method: "signTransaction", data: signedTxBase64))
            }
            if case let .signAndSendTransaction(params) = solanaRequest {
                let response = try await self.perform(
                    request: SolanaRpcRequest.signTransaction(params: SolanaSignTransactionParams(transaction: params.transaction))
                )
                guard let signedTx = Data(base64Encoded: response.response.data) else {
                    throw PrivyError(.embeddedWalletFailure(reason: .rpcError))
                }

                let jsonrpc = try SolanaJsonRpcClient(rpcUrl: params.rpcUrl)
                let hash = try await jsonrpc.broadcast(transaction: signedTx, with: params.options)

                return .init(address: account.address, response: .init(method: "signAndSendTransaction", data: hash))
            }
        }

        // When making an RPC call:
        // the request's "address" field should be the primary wallet's address (hdWalletIndex == 0)
        // and the "hdWalletIndex" field should be the HD index of the target wallet.
        // The wallet channel is responsible for ensuring wallet is connected before making the rpc call
        let result = try await self.rpc(
            data: WalletRpcRequestData(
                accessToken: auth.authToken,
                // primary wallet's entropy info
                entropyId: primaryWallet.entropyId,
                entropyIdVerifier: primaryWallet.entropyIdVerifier,
                // Chain type and HD index of the target wallet
                chainType: targetWallet.chainType.rawValue,
                hdWalletIndex: targetWallet.hdWalletIndex,
                request: request
            )
        )

        return result.data
    }

    private func rpc<T>(data: WalletRpcRequestData<T>) async throws -> WalletRpcResponse where T: Encodable {
        try await walletConnector.ensurePrimaryEmbeddedWalletConnected()
        do {
            return try await self.handler.rpc(data: data)
        } catch {
            // the webview can require wallet recovery at any time, so we need to react accordingly.
            // if so, then we must re-attempt the rpc post-recovery.
            // See the docs on `handleRecoveryIfNeededOrThrow` for details.
            try await walletConnector.handleRecoveryIfNeededOrThrow(error: error)
            return try await self.handler.rpc(data: data)
        }
    }

    private func getEmbeddedWalletWithAddress(_ address: String) async -> (any EmbeddedWalletAccount)? {
        guard let auth = try? authManager.ensureAuthenticated() else { return nil }

        return auth.user.linkedAccounts.getEmbeddedWalletAccountByAddress(address: address)
    }
}
