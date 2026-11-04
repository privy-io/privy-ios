/// A blockchain type
public enum ChainType: String, Codable, Sendable {
    /// The Ethereum blockchain type
    case ethereum = "ethereum"
    /// The Solana blockchain type
    case solana = "solana"

    internal init(chainType: String) {
        self = switch chainType {
        case "solana": .solana
        default: .ethereum
        }
    }
}
