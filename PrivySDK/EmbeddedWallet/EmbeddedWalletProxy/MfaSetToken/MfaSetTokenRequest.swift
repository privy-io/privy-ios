import Foundation

internal struct MfaSetTokenRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .setMfaToken
    internal let data: MfaSetTokenRequestData
}

internal struct MfaSetTokenRequestData: Encodable {
    internal let accessToken: String
    internal let mfaToken: String
}
