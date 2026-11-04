internal typealias EthereumWalletAddress = String

/// ETH "quantity" properties, represented as a hex string, while supporting decoding from an Int value.
internal struct Quantity: Decodable {
    internal let hexString: String

    internal var number: Int? {
        Int(hexString.dropFirst(2), radix: 16)
    }

    internal init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Int.self) {
            self = .init(from: number)
        } else if let hex = try? container.decode(String.self), hex.isHexEncoded {
            self = .init(hexString: hex)
        } else {
            throw DecodingError.typeMismatch(Quantity.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode as a Quantity"))
        }
    }

    internal init(hexString: String) {
        self.hexString = hexString
    }

    internal init(from number: Int) {
        self.hexString = String(format: "0x%02X", number)
    }
}

internal typealias EIP2718TransactionType = Int

internal struct UnsignedEthereumTransaction: Decodable {
    /** The address the transaction is sent from. Must be hexadecimal formatted. */
    internal let from: EthereumWalletAddress?
    /** Destination address of the transaction. */
    internal let to: EthereumWalletAddress?
    /** (optional) The nonce to be used for the transaction (hexadecimal or number). */
    internal let nonce: Quantity?
    /** (optional) The max units of gas that can be used by this transaction (hexadecimal or number). */
    internal let gasLimit: Quantity?
    /** (optional) The price (in wei) per unit of gas for this transaction (hexadecimal or number), for use in non EIP-1559 transactions (type 0 or 1). */
    internal let gasPrice: Quantity?
    /** Data to send to the receiving address, especially when calling smart contracts. Must be hexadecimal formatted. */
    internal let data: String?
    /** (optional) The value (in wei) be sent with the transaction (hexadecimal or number). */
    internal let value: Quantity?
    /** The chain ID of network your transaction will  be sent on (hexadecimal or number). */
    internal let chainId: Quantity?
    /** (optional) The EIP-2718 transction type (e.g. `2` for EIP-1559 transactions). */
    internal let type: EIP2718TransactionType?
    /** (optional) The maxFeePerGas (hexadecimal or number) to be used in this transaction, for use in EIP-1559 (type 2) transactions. */
    internal let maxFeePerGas: Quantity?
    /** (optional) The maxPriorityFeePerGas (hexadecimal or number) to be used in this transaction, for use in EIP-1559 (type 2) transactions. */
    internal let maxPriorityFeePerGas: Quantity?
}
