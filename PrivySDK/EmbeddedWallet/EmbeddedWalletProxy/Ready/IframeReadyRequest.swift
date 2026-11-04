import Foundation

// MARK: - Ready

internal struct Empty: Codable {}

internal struct IframeReadyRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .ready
    internal private(set) var data: Empty = Empty()
}

internal struct IframeReadyResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .ready
    internal private(set) var data: Empty = Empty()
}
