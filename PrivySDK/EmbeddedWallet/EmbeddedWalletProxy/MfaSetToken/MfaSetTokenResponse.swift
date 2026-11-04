import Foundation

internal struct MfaSetTokenResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .setMfaToken
    internal let data: MfaSetTokenResponseData
}

internal struct MfaSetTokenResponseData: Decodable {
}
