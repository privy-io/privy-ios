import Foundation

internal struct ClearMfaResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .clearMfa
    internal let data: ClearMfaResponseData
}

internal struct ClearMfaResponseData: Decodable {
}
