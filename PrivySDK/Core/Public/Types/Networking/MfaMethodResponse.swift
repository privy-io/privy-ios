import Foundation

// MARK: - MfaMethod

internal enum MfaMethodResponse {
    case sms(SmsMfaMethodResponse)
    case totp(TotpMfaMethodResponse)
    case passkey(PasskeyMfaMethodResponse)
    case unknown
}

extension MfaMethodResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "sms":
            let data = try SmsMfaMethodResponse(from: decoder)
            self = .sms(data)
        case "totp":
            let data = try TotpMfaMethodResponse(from: decoder)
            self = .totp(data)
        case "passkey":
            let data = try PasskeyMfaMethodResponse(from: decoder)
            self = .passkey(data)
        default:
            self = .unknown
        }
    }
}

// MARK: - SMS MFA

internal struct SmsMfaMethodResponse: Decodable {
    internal let verifiedAt: SecondsSinceEpoch

    private enum CodingKeys: String, CodingKey {
        case verifiedAt = "verified_at"
    }
}

// MARK: - TOTP MFA

internal struct TotpMfaMethodResponse: Decodable {
    internal let verifiedAt: SecondsSinceEpoch

    private enum CodingKeys: String, CodingKey {
        case verifiedAt = "verified_at"
    }
}

// MARK: - Passkey MFA

internal struct PasskeyMfaMethodResponse: Decodable {
    internal let verifiedAt: SecondsSinceEpoch

    private enum CodingKeys: String, CodingKey {
        case verifiedAt = "verified_at"
    }
}
