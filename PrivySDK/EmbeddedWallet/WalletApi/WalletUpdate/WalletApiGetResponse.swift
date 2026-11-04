import Foundation

// MARK: - GET /api/v1/wallets/{wallet_id} response

internal struct WalletApiGetResponse: Decodable {
    internal let id: String
    internal let address: String
    internal let chainType: String
    internal let additionalSigners: [AdditionalSignerResponse]

    private enum CodingKeys: String, CodingKey {
        case id
        case address
        case chainType = "chain_type"
        case additionalSigners = "additional_signers"
    }
}
