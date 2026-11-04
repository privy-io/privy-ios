import Foundation

// MARK: - User Signer Sign Response

internal struct UserSignerSignResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .signWithUserSigner
    internal let data: UserSignerSignResponseData
}

internal struct UserSignerSignResponseData: Decodable {
    public let signature: Data

    private enum CodingKeys: String, CodingKey {
        case signature
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base64String = try container.decode(String.self, forKey: .signature)
        guard let data = Data(base64Encoded: base64String) else {
            throw DecodingError.dataCorruptedError(forKey: .signature, in: container, debugDescription: "Invalid base64 string")
        }
        self.signature = data
    }
}
