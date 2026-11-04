import Foundation

// MARK: - Set Password

internal struct WalletSetPasswordRequestData: Codable {
    internal let accessToken: String
    internal let address: String
    internal let recoveryPassword: String
}

internal struct WalletSetPasswordRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .setPassword
    internal let data: WalletSetPasswordRequestData
}
