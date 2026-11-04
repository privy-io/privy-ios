import Foundation

/// A paginated response of wallet transactions.
public struct TransactionsPage: Sendable {
    /// The transactions in this page.
    public let transactions: [WalletTransaction]
    /// Cursor for fetching the next page. `nil` when there are no more results.
    public let nextCursor: String?
}

/// A transaction associated with an embedded wallet.
public struct WalletTransaction: Sendable {
    /// CAIP-2 chain identifier (e.g. `"eip155:11155111"` for Sepolia).
    public let caip2: String
    /// On-chain transaction hash. Nil if not yet broadcasted.
    public let transactionHash: String?
    /// ERC-4337 user operation hash. Present only for smart contract wallet transactions.
    public let userOperationHash: String?
    /// Current lifecycle status of the transaction.
    public let status: TransactionStatus
    /// Unix timestamp in milliseconds when the transaction was created.
    public let createdAt: Int
    /// Whether gas fees were sponsored by Privy.
    public let sponsored: Bool
    /// Privy's internal transaction identifier. Nil for externally-initiated transactions.
    public let privyTransactionId: String?
    /// ID of the wallet associated with this transaction.
    public let walletId: String
    /// Parsed transfer details. Nil for non-transfer transaction types.
    public let details: TransactionDetails?
}

/// Lifecycle status of a blockchain transaction.
public enum TransactionStatus: Sendable {
    /// The transaction has been broadcasted to the network.
    case broadcasted
    /// The transaction has been confirmed on-chain.
    case confirmed
    /// The transaction execution was reverted.
    case executionReverted
    /// The transaction failed.
    case failed
    /// The transaction was replaced by another transaction.
    case replaced
    /// The transaction has been finalized on-chain.
    case finalized
    /// The RPC provider returned an error.
    case providerError
    /// The transaction is pending.
    case pending
    /// A status value not yet recognized by this SDK version. Contains the raw server string for debugging.
    case unknown(String)
}

/// The direction of a wallet transfer.
public enum TransactionType: Sendable {
    /// A transfer sent from this wallet.
    case transferSent
    /// A transfer received by this wallet.
    case transferReceived
    /// A transaction type not yet recognized by this SDK version. Contains the raw server string for debugging.
    case unknown(String)
}

/// Parsed details of a transfer transaction.
public struct TransactionDetails: Sendable {
    /// The transfer direction (sent or received).
    public let type: TransactionType
    /// Wallet address of the sender.
    public let sender: String
    /// Privy user ID of the sender, if the address belongs to a Privy user.
    public let senderPrivyUserId: String?
    /// Wallet address of the recipient.
    public let recipient: String
    /// Privy user ID of the recipient, if the address belongs to a Privy user.
    public let recipientPrivyUserId: String?
    /// Chain name where the transfer occurred.
    public let chain: String
    /// Named asset (e.g. `"eth"`, `"usdc"`) or token contract/mint address.
    public let asset: String
    /// Raw token amount as a string to avoid floating-point precision loss.
    public let rawValue: String
    /// Number of decimal places for interpreting ``rawValue``.
    public let rawValueDecimals: Int
    /// Human-readable formatted amounts keyed by currency or asset name.
    public let displayValues: [String: String]
}

/// Supported chains for transaction history queries.
public enum TransactionChain: Sendable {
    /// Ethereum mainnet.
    case ethereum
    /// Arbitrum One.
    case arbitrum
    /// Avalanche C-Chain.
    case avalanche
    /// Base.
    case base
    /// Base Sepolia testnet.
    case baseSepolia
    /// BNB Smart Chain.
    case bsc
    /// Tempo.
    case tempo
    /// Linea.
    case linea
    /// Optimism.
    case optimism
    /// Polygon.
    case polygon
    /// Solana mainnet.
    case solana
    /// Ethereum Sepolia testnet.
    case sepolia
    /// A custom chain not covered by the predefined cases, specified as the chain name slug
    /// accepted by the API (e.g. `"arbitrum-nova"`).
    case custom(String)

    internal var queryValue: String {
        switch self {
        case .ethereum: "ethereum"
        case .arbitrum: "arbitrum"
        case .avalanche: "avalanche"
        case .base: "base"
        case .baseSepolia: "base_sepolia"
        case .bsc: "bsc"
        case .tempo: "tempo"
        case .linea: "linea"
        case .optimism: "optimism"
        case .polygon: "polygon"
        case .solana: "solana"
        case .sepolia: "sepolia"
        case .custom(let value): value
        }
    }
}

/// Parameters for fetching transaction history.
public struct GetTransactionsParams: Sendable {
    /// The chain to query transactions on (required).
    public let chain: TransactionChain
    /// Named assets to filter by (e.g. `["eth", "usdc"]`). Mutually exclusive with ``tokens``.
    public let assets: [String]?
    /// Token contract/mint addresses to filter by. Mutually exclusive with ``assets``.
    public let tokens: [String]?
    /// Filter by a specific transaction hash. EVM: `0x` + 64 hex characters. Solana: 87-88 base58 characters.
    public let txHash: String?
    /// Maximum number of transactions to return per page.
    public let limit: Int?
    /// Pagination cursor from a previous response's ``TransactionsPage/nextCursor``.
    public let cursor: String?
    /// Whether to include transactions from archived wallets. Defaults to false.
    public let includeArchived: Bool?

    public init(
        chain: TransactionChain,
        assets: [String]? = nil,
        tokens: [String]? = nil,
        txHash: String? = nil,
        limit: Int? = nil,
        cursor: String? = nil,
        includeArchived: Bool? = nil
    ) {
        self.chain = chain
        self.assets = assets
        self.tokens = tokens
        self.txHash = txHash
        self.limit = limit
        self.cursor = cursor
        self.includeArchived = includeArchived
    }
}
