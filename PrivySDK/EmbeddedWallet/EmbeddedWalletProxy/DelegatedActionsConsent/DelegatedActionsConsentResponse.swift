import Foundation

// MARK: - Delegated Actions Consent Response

internal struct DelegateActionsResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .delegatedActionsConsent
    internal let data: DelegateActionsResponseData
}

internal struct DelegateActionsResponseData: Decodable, Sendable {
    internal let success: Bool
}
