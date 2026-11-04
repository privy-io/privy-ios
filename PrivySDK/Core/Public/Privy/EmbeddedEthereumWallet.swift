import Foundation

/// An embedded ethereum wallet that you can operate on via its `provider` property
public protocol EmbeddedEthereumWallet: EmbeddedWallet {
    /// The ethereum provider to use for acting on wallet
    var provider: EmbeddedEthereumWalletProvider { get }
}

public extension EmbeddedEthereumWallet {
    /// The chain of the wallet, i.e. "ethereum"
    var chainType: ChainType { .ethereum }
}
