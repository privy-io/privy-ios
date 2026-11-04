import Foundation

// MARK: - Create

internal struct ChainAgnosticCreateAdditionalWalletRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .createAdditional
    internal let data: ChainAgnosticCreateAdditionalWalletRequestData
}

internal struct ChainAgnosticCreateAdditionalWalletRequestData: Encodable {
    internal let chainType: String
    internal let entropyId: String
    internal let entropyIdVerifier: String
    internal let accessToken: String
    internal let hdWalletIndex: Int

    internal init(
        chainType: ChainType,
        accessToken: String,
        hdWalletIndex: Int,
        entropyWallet: any EmbeddedWalletAccount
    ) {
        self.chainType = chainType.rawValue
        self.accessToken = accessToken
        self.hdWalletIndex = hdWalletIndex
        self.entropyId = entropyWallet.entropyId
        self.entropyIdVerifier = entropyWallet.entropyIdVerifier
    }
}
