import Foundation

/// An embedded solana wallet that you can operate on via its `provider` property
public protocol EmbeddedSolanaWallet: EmbeddedWallet {
    /// The solana provider to use for acting on wallet
    var provider: EmbeddedSolanaWalletProvider { get }
}

public extension EmbeddedSolanaWallet {
    /// The chain of the wallet, i.e. "solana"
    var chainType: ChainType { .solana }
}
