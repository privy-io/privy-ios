import Foundation

// MARK: Passkey /register/init and /link/init API response model

internal struct InitPasskeyRegistrationApiResponse: Decodable {
    internal let options: PasskeyRegistrationApiOptions
}

internal struct PasskeyRegistrationApiOptions: Codable {
    internal let challenge: String
    internal let rp: ApiRelyingParty
    internal let user: ApiUserInfo
    internal let pubKeyCredParams: [ApiPubKeyCredParam]
    internal let timeout: Int?
    internal let excludeCredentials: [ApiCredentialDescriptor]?
    internal let authenticatorSelection: ApiAuthenticatorSelection?
    internal let attestation: String?

    private enum CodingKeys: String, CodingKey {
        case challenge
        case rp
        case user
        case pubKeyCredParams = "pub_key_cred_params"
        case timeout
        case excludeCredentials = "exclude_credentials"
        case authenticatorSelection = "authenticator_selection"
        case attestation
    }
}

internal struct ApiRelyingParty: Codable {
    internal let id: String
    internal let name: String
}

internal struct ApiUserInfo: Codable {
    internal let id: String
    internal let name: String
    internal let displayName: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
    }
}

internal struct ApiPubKeyCredParam: Codable {
    internal let type: String
    internal let alg: Int
}

internal struct ApiCredentialDescriptor: Codable {
    internal let type: String
    internal let id: String
    internal let transports: [String]?
}

internal struct ApiAuthenticatorSelection: Codable {
    internal let authenticatorAttachment: String?
    internal let requireResidentKey: Bool?
    internal let residentKey: String?
    internal let userVerification: String?

    private enum CodingKeys: String, CodingKey {
        case authenticatorAttachment = "authenticator_attachment"
        case requireResidentKey = "require_resident_key"
        case residentKey = "resident_key"
        case userVerification = "user_verification"
    }
}

// MARK: Passkeys /register and /link API model

internal struct PasskeyRegisterRequest: Codable {
    internal let authenticatorResponse: PasskeyRegistrationCredential
    internal let relyingParty: String

    private enum CodingKeys: String, CodingKey {
        case authenticatorResponse = "authenticator_response"
        case relyingParty = "relying_party"
    }
}

internal struct PasskeyRegistrationCredential: Codable {
    internal let type: String
    internal let id: String
    internal let rawId: String
    internal let response: AuthenticatorAttestationResponse
    internal let authenticatorAttachment: String?
    internal let clientExtensionResults: [String: String]

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case rawId = "raw_id"
        case response
        case authenticatorAttachment = "authenticator_attachment"
        case clientExtensionResults = "client_extension_results"
    }
}

internal struct AuthenticatorAttestationResponse: Codable {
    internal let clientDataJSON: String
    internal let attestationObject: String
    internal let transports: [String]?
    internal let publicKeyAlgorithm: Int?
    internal let publicKey: String?
    internal let authenticatorData: String?

    private enum CodingKeys: String, CodingKey {
        case clientDataJSON = "client_data_json"
        case attestationObject = "attestation_object"
        case transports
        case publicKeyAlgorithm = "public_key_algorithm"
        case publicKey = "public_key"
        case authenticatorData = "authenticator_data"
    }
}

// MARK: /authenticate/init API model

internal struct PasskeyAuthenticationOptionsResponse: Decodable {
    internal let options: PasskeyAuthenticationApiOptions
}

internal struct PasskeyAuthenticationApiOptions: Decodable {
    internal let challenge: String
    internal let timeout: Int?
    internal let rpId: String
    internal let allowCredentials: [ApiCredentialDescriptor]?
    internal let userVerification: String?

    private enum CodingKeys: String, CodingKey {
        case challenge
        case timeout
        case rpId = "rp_id"
        case allowCredentials = "allow_credentials"
        case userVerification = "user_verification"
    }
}

// MARK: Passkeys /authenticate API model

internal struct PasskeyAuthenticateRequest: Codable {
    internal let authenticatorResponse: PasskeyAuthenticationCredential
    internal let challenge: String
    internal let relyingParty: String

    private enum CodingKeys: String, CodingKey {
        case authenticatorResponse = "authenticator_response"
        case challenge
        case relyingParty = "relying_party"
    }
}

internal struct PasskeyAuthenticationCredential: Codable {
    internal let type: String
    internal let id: String
    internal let rawId: String
    internal let response: AuthenticatorAssertionResponse
    internal let authenticatorAttachment: String?
    internal let clientExtensionResults: [String: String]

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case rawId = "raw_id"
        case response
        case authenticatorAttachment = "authenticator_attachment"
        case clientExtensionResults = "client_extension_results"
    }
}

internal struct AuthenticatorAssertionResponse: Codable {
    internal let clientDataJSON: String
    internal let authenticatorData: String
    internal let signature: String
    internal let userHandle: String?

    private enum CodingKeys: String, CodingKey {
        case clientDataJSON = "client_data_json"
        case authenticatorData = "authenticator_data"
        case signature
        case userHandle = "user_handle"
    }
}
