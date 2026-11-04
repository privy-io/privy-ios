import Foundation

internal struct SiwsAuthenticateRequestBody: Encodable {
    internal let address: String?

    internal let connectorType: String?

    internal let message: String

    internal let signature: String

    internal let walletClientType: String?

    internal let messageType: MessageType

    internal let mode: Mode

    internal enum CodingKeys: String, CodingKey {
        case address
        case connectorType = "connectorType"
        case message
        case signature
        case walletClientType = "walletClientType"
        case messageType = "message_type"
        case mode
    }

    internal enum MessageType: String, Encodable {
        case transaction = "transaction"
        case plain = "plain"
    }

    internal enum Mode: String, Encodable {
        case noSignup = "no-signup"
        case loginOrSignUp = "login-or-sign-up"
    }
}

internal struct SiwsInitRequestBody: Encodable {
    internal let address: String
}

internal struct SiwsInitResponseBody: Decodable {
    internal let nonce: String
    internal let address: String
    internal let expiresAt: String

    private enum CodingKeys: String, CodingKey {
        case nonce
        case address
        case expiresAt = "expires_at"
    }
}

internal struct SiwsLinkRequestBody: Encodable {
    internal let address: String?

    internal let connectorType: String?

    internal let message: String

    internal let signature: String

    internal let walletClientType: String?

    internal let messageType: MessageType

    internal enum CodingKeys: String, CodingKey {
        case address
        case connectorType = "connectorType"
        case message
        case signature
        case walletClientType = "walletClientType"
        case messageType = "message_type"
    }

    internal enum MessageType: String, Encodable {
        case transaction = "transaction"
        case plain = "plain"
    }
}

internal struct SiwsUnlinkRequestBody: Encodable {
    internal let address: String
}
