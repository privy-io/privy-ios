import Foundation

// MARK: - Delegated Actions Consent Request

internal struct DelegateActionsRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .delegatedActionsConsent
    internal let data: DelegateActionsRequestData
}

internal struct DelegateActionsRequestData: Encodable, Sendable {
    internal let accessToken: String
    internal let rootWallet: RootWalletForDelegation
    internal let delegatedWallets: [DelegatedWallet]
}

internal struct RootWalletForDelegation: Encodable, Sendable {
    internal let address: String
    internal let chainType: String
    internal let imported: Bool
}

internal struct DelegatedWallet: Encodable, Sendable {
    internal let address: String
    internal let chainType: String
    internal let walletIndex: Int
}
