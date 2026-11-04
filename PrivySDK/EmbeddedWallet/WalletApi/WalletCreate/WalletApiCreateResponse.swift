import Foundation

internal struct WalletApiCreateResponse: Decodable {
    internal let id: String
    internal let address: String
    internal let chainType: ChainType

    private enum CodingKeys: String, CodingKey {
        case id
        case address
        case chainType = "chain_type"
    }
}
