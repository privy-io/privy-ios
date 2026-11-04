public struct SolanaCluster: Sendable {
    /// The CAIP-2 formatted ID for the cluster
    public let caip2: String

    /// The RPC URL for the cluster
    public let rpcUrl: String

    /// Describe a Solana cluster by providing the CAIP-2 ID and RPC URL directly.
    /// When possible, prefer the predefined options such as `.mainnet` or `.devnet`.
    public init(caip2: String, rpcUrl: String) {
        self.caip2 = caip2
        self.rpcUrl = rpcUrl
    }

    /// Live production environment for deployed applications
    /// Genesis hash: 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpDycWrpd9ExYktWt
    public static let mainnet = SolanaCluster(caip2: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", rpcUrl: "https://api.mainnet-beta.solana.com")

    /// Public testing and development
    /// Genesis hash: EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG
    public static let devnet = SolanaCluster(caip2: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", rpcUrl: "https://api.devnet.solana.com")

    /// Validator and stress testing
    /// Genesis hash: 4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY
    public static let testnet = SolanaCluster(caip2: "solana:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z", rpcUrl: "https://api.testnet.solana.com")

    /// Set a custom RPC URL to use in place of the default public one.
    /// This can be helpful in avoiding rate limiting issues.
    ///
    /// - Parameters:
    ///     - rpcUrl: The RPC URL to use in place of the default public one.
    ///
    /// - Returns: A new SolanaCluster with the updated RPC URL.
    public func with(rpcUrl: String) -> SolanaCluster {
        return Self(caip2: self.caip2, rpcUrl: rpcUrl)
    }
}
