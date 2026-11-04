import Foundation

internal struct ClearMfaRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .clearMfa
    internal let data: ClearMfaRequestData
}

internal struct ClearMfaRequestData: Encodable {
    internal let userId: String
}
