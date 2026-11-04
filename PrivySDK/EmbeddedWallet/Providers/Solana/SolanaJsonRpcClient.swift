import Foundation
internal import FactoryKit

internal struct SolanaJsonRpcClient {
    private let rpcUrl: URL
    private let logger: Logger = resolve(\PrivyContainer.logger)

    internal init(rpcUrl: String) throws {
        guard let url = URL(string: rpcUrl) else {
            throw PrivyError(.embeddedWalletFailure(reason: .jsonRpcError(message: "invalid RPC url")))
        }
        self.rpcUrl = url
    }

    internal func broadcast(transaction: Data, with options: SolanaSendOptions?) async throws -> String {
        var request = URLRequest(url: self.rpcUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let signedTransaction = transaction.base64EncodedString()
        let rpcRequest = RpcRequest(
            jsonrpc: "2.0",
            id: await JsonRpcMessageIdGenerator.shared.nextMessageId,
            method: "sendTransaction",
            params: SendTransactionParams(
                signedTransaction: signedTransaction,
                options: SendTransactionOptions(from: options)
            )
        )

        request.httpBody = try JSONEncoder().encode(rpcRequest)

        logger.debug("JSON-RPC request: \(request.httpMethod!) \(request.url!)")
        logger.verbose("JSON-RPC request body: \(String(data: request.httpBody ?? Data(), encoding: .utf8)!)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw PrivyError(.embeddedWalletFailure(reason: .jsonRpcError(message: "invalid HTTP response")))
        }

        logger.debug("JSON-RPC response: \(response.statusCode) \(response.url!)")
        logger.debug("JSON-RPC response body: \(String(describing: String(data: data, encoding: .utf8)))")

        guard (200 ..< 300).contains(response.statusCode) else {
            if let content = String(data: data, encoding: .utf8) {
                throw PrivyError(.embeddedWalletFailure(reason: .jsonRpcError(message: content)))
            } else {
                let status = response.statusCode
                let description = HTTPURLResponse.localizedString(forStatusCode: status)
                throw PrivyError(.embeddedWalletFailure(reason: .jsonRpcError(message: "\(status) \(description)")))
            }
        }

        let rpcResponse = try JSONDecoder().decode(RpcResponse.self, from: data)

        if let error = rpcResponse.error {
            throw PrivyError(.embeddedWalletFailure(reason: .jsonRpcError(message: error.description)))
        }

        guard let result = rpcResponse.result else {
            throw PrivyError(.embeddedWalletFailure(reason: .jsonRpcError(message: "response is empty")))
        }

        return result
    }

    private struct RpcRequest<Params: Encodable>: Encodable {
        let jsonrpc: String
        let id: String
        let method: String
        let params: Params
    }

    private struct SendTransactionParams: Encodable {
        let signedTransaction: String
        let options: SendTransactionOptions

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(signedTransaction)
            try container.encode(options)
        }
    }

    private struct SendTransactionOptions: Encodable {
        let encoding: String = "base64"
        let skipPreflight: Bool?
        let preflightCommitment: String?
        let maxRetries: Int?
        let minContextSlot: Int?

        internal init(from options: SolanaSendOptions?) {
            self.skipPreflight = options?.skipPreflight
            self.preflightCommitment = options?.preflightCommitment?.rawValue
            self.maxRetries = options?.maxRetries
            self.minContextSlot = options?.minContextSlot
        }
    }

    private struct RpcResponse: Decodable {
        let result: String?
        let error: RpcError?
    }

    private struct RpcError: Decodable {
        let code: Int
        let message: String

        fileprivate var description: String {
            "[\(code)] \(message)"
        }
    }

    private actor JsonRpcMessageIdGenerator {
        fileprivate static let shared = JsonRpcMessageIdGenerator()

        private var _nextMessageId = UInt64(0)

        fileprivate var nextMessageId: String {
            self._nextMessageId += 1
            return String(_nextMessageId)
        }
    }
}
