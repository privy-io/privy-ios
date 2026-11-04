import Foundation

internal struct WalletSetPasswordResponseData {
    internal let address: String
}

extension WalletSetPasswordResponseData: Codable {}

internal struct WalletSetPasswordResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .setPassword
    internal let data: WalletSetPasswordResponseData
}
