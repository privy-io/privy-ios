import Foundation

// MARK: - Passkey MFA Models

/// Request body for `/api/v1/mfa/passkeys/init`
internal struct PasskeyMfaInitRequest: Encodable {
    internal let relyingParty: String?

    private enum CodingKeys: String, CodingKey {
        case relyingParty = "relying_party"
    }
}

/// Response from `/api/v1/mfa/passkeys/init`
internal struct PasskeyMfaInitResponse: Decodable {
    internal let options: PasskeyAuthenticationApiOptions
    internal let relyingParty: String?

    private enum CodingKeys: String, CodingKey {
        case options
        case relyingParty = "relying_party"
    }
}

/// Request body for `/api/v1/mfa/passkeys/verify`
internal struct PasskeyMfaVerifyRequest: Encodable {
    internal let authenticatorResponse: PasskeyAuthenticationCredential
    internal let relyingParty: String?

    private enum CodingKeys: String, CodingKey {
        case authenticatorResponse = "authenticator_response"
        case relyingParty = "relying_party"
    }
}

/// Request body for `/api/v1/mfa/passkeys/enrollment`
internal struct PasskeyMfaEnrollmentRequest: Encodable {
    internal let credentialIds: [String]
    internal let removeForLogin: Bool

    private enum CodingKeys: String, CodingKey {
        case credentialIds = "credential_ids"
        case removeForLogin = "remove_for_login"
    }
}
