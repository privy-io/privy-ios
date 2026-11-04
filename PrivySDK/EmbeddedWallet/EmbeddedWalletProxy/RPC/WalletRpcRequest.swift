import Foundation

// Chain Agnostic RPC request
internal struct WalletRpcRequest<RequestData: Encodable & Sendable>: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .rpc
    internal let data: RequestData
}

internal struct WalletRpcRequestData<Request: WalletRpcRequestBody>: Encodable, Sendable {
    internal let accessToken: String
    internal let entropyId: String
    internal let entropyIdVerifier: String
    internal let chainType: String
    internal let hdWalletIndex: Int?
    internal let request: Request
}

internal protocol WalletRpcRequestBody: Encodable & Sendable {
    var method: String { get }
}
