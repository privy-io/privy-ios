import Foundation

internal struct WalletRecoverResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .recover
    internal let data: ChainAgnosticWalletRecoverResponseData
}

internal struct ChainAgnosticWalletRecoverResponseData: Codable {
    public let entropyId: String
}
