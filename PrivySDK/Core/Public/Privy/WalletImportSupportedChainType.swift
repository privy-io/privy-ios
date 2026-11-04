import Foundation

/// A chain that wallets can be imported on.
///
/// This is separate from ``ChainType`` because the SDK may support chains that wallet import
/// doesn't, and wallet import may support more chains over time.
public enum WalletImportSupportedChainType: String, Encodable, Sendable {
    /// The Ethereum blockchain type
    case ethereum = "ethereum"
    /// The Solana blockchain type
    case solana = "solana"
}
