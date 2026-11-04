import Foundation

// MARK: - User Signer Sign Request

internal struct UserSignerSignRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .signWithUserSigner
    internal let data: UserSignerSignRequestData
}

internal struct UserSignerSignRequestData: Encodable {
    internal let accessToken: String
    internal let message: Data

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case message
    }

    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(message.base64EncodedString(), forKey: .message)
    }
}
