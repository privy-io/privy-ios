import Foundation

internal struct ChainAgnosticCreateAdditionalWalletResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .createAdditional
    internal let data: ChainAgnosticCreateAdditionalWalletResponseData
}

internal struct ChainAgnosticCreateAdditionalWalletResponseData: Codable {
    public let address: String
}
