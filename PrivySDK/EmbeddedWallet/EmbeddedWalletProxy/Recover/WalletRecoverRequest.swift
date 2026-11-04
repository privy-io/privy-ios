import Foundation

// MARK: - Recover

internal struct ChainAgnosticWalletRecoverRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .recover
    internal let data: ChainAgnosticWalletRecoverRequestData
}

internal struct ChainAgnosticWalletRecoverRequestData: Codable {
    internal let accessToken: String
    internal let entropyId: String
    internal let entropyIdVerifier: String
}
