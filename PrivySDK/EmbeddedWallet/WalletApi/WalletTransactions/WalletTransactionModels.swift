import Foundation

internal struct WalletTransactionsResponse: Decodable {
    internal let transactions: [TransactionApiModel]
    internal let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case transactions
        case nextCursor = "next_cursor"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactions = try container.decode([TransactionApiModel].self, forKey: .transactions)
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

internal struct TransactionApiModel: Decodable {
    internal let caip2: String
    internal let transactionHash: String?
    internal let userOperationHash: String?
    internal let status: String
    internal let createdAt: Int
    internal let sponsored: Bool
    internal let privyTransactionId: String?
    internal let walletId: String
    internal let details: TransactionDetailsApiModel?

    private enum CodingKeys: String, CodingKey {
        case caip2
        case transactionHash = "transaction_hash"
        case userOperationHash = "user_operation_hash"
        case status
        case createdAt = "created_at"
        case sponsored
        case privyTransactionId = "privy_transaction_id"
        case walletId = "wallet_id"
        case details
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caip2 = try container.decode(String.self, forKey: .caip2)
        transactionHash = try container.decodeIfPresent(String.self, forKey: .transactionHash)
        userOperationHash = try container.decodeIfPresent(String.self, forKey: .userOperationHash)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decode(Int.self, forKey: .createdAt)
        sponsored = try container.decodeIfPresent(Bool.self, forKey: .sponsored) ?? false
        privyTransactionId = try container.decodeIfPresent(String.self, forKey: .privyTransactionId)
        walletId = try container.decode(String.self, forKey: .walletId)
        details = try container.decodeIfPresent(TransactionDetailsApiModel.self, forKey: .details)
    }
}

internal struct TransactionDetailsApiModel: Decodable {
    internal let type: String
    internal let sender: String
    internal let senderPrivyUserId: String?
    internal let recipient: String
    internal let recipientPrivyUserId: String?
    internal let chain: String
    internal let asset: String
    internal let rawValue: String
    internal let rawValueDecimals: Int
    internal let displayValues: [String: String]

    private enum CodingKeys: String, CodingKey {
        case type
        case sender
        case senderPrivyUserId = "sender_privy_user_id"
        case recipient
        case recipientPrivyUserId = "recipient_privy_user_id"
        case chain
        case asset
        case rawValue = "raw_value"
        case rawValueDecimals = "raw_value_decimals"
        case displayValues = "display_values"
    }
}
