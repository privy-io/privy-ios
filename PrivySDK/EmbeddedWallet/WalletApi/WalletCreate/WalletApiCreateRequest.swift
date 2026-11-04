import Foundation

internal struct WalletApiCreateRequest: Encodable {
    internal let chainType: ChainType

    private enum CodingKeys: String, CodingKey {
        case chainType = "chain_type"
    }
}
