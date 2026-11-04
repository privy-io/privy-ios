// Chain Agnostic RPC response body
internal struct WalletRpcResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .rpc
    internal let data: WalletRpcResponseData
}

internal struct WalletRpcResponseData: Decodable, Sendable {
    public let address: String
    public let response: Response

    internal struct Response: Decodable, Sendable {
        internal let method: String
        internal let data: String

        private enum CodingKeys: CodingKey {
            case method
            case data
        }

        internal init(method: String, data: String) {
            self.method = method
            self.data = data
        }

        // TODO: Move to proper enum based parsing like the one in WalletApiRpcResponse
        internal init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.method = try container.decode(String.self, forKey: .method)

            if (self.method == "signMessage") {
                // SOLANA message signatures return an object instead of a raw string
                let data = try container.decode(SignMessageResponseData.self, forKey: .data)
                self.data = data.signature
            } else {
                self.data = try container.decode(String.self, forKey: .data)
            }
        }
    }
}
