import Foundation

// MARK: - Chain Agnostic Connect Flow

internal struct ChainAgnosticWalletConnectRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .connect
    internal let data: ChainAgnosticWalletConnectRequestData
}

internal struct ChainAgnosticWalletConnectRequestData: Codable {
    internal let accessToken: String
    internal let chainType: String
    internal let entropyId: String
    internal let entropyIdVerifier: String

    internal init(wallet: any EmbeddedWalletAccount, accessToken: String) {
        self.accessToken = accessToken
        self.chainType = wallet.chainType.rawValue
        self.entropyId = wallet.entropyId
        self.entropyIdVerifier = wallet.entropyIdVerifier
    }
}

// New, chain agnostic wallet connect response type
internal struct ChainAgnosticWalletConnectResponseData: Codable {
    public let entropyId: String
}

internal struct ChainAgnosticWalletConnectResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .connect
    internal let data: ChainAgnosticWalletConnectResponseData
}
