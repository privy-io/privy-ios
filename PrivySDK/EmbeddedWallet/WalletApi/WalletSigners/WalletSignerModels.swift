import Foundation

// MARK: - Additional signer types used in wallet GET/PATCH responses and requests

internal struct AdditionalSignerResponse: Decodable {
    internal let signerId: String
    internal let overridePolicyIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case signerId = "signer_id"
        case overridePolicyIds = "override_policy_ids"
    }
}

internal struct AdditionalSignerParam: Encodable {
    internal let signerId: String
    internal let overridePolicyIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case signerId = "signer_id"
        case overridePolicyIds = "override_policy_ids"
    }
}
