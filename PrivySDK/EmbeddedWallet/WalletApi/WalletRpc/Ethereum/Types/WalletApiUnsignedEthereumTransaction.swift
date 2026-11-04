internal struct WalletApiUnsignedEthereumTransaction: Encodable {
    /** The address the transaction is sent from. Must be hexadecimal formatted. */
    internal let from: String?
    /** Destination address of the transaction. */
    internal let to: String?
    /** (optional) The nonce to be used for the transaction (hexadecimal or number). */
    internal let nonce: String?
    /** (optional) The max units of gas that can be used by this transaction (hexadecimal or number). */
    internal let gasLimit: String?
    /** (optional) The price (in wei) per unit of gas for this transaction (hexadecimal or number), for use in non EIP-1559 transactions (type 0 or 1). */
    internal let gasPrice: String?
    /** Data to send to the receiving address, especially when calling smart contracts. Must be hexadecimal formatted. */
    internal let data: String?
    /** (optional) The value (in wei) be sent with the transaction (hexadecimal or number). */
    internal let value: String?
    /** The chain ID of network your transaction will  be sent on (number). */
    internal let chainId: Int?
    /** (optional) The EIP-2718 transction type (e.g. `2` for EIP-1559 transactions). */
    internal let type: Int?
    /** (optional) The maxFeePerGas (hexadecimal or number) to be used in this transaction, for use in EIP-1559 (type 2) transactions. */
    internal let maxFeePerGas: String?
    /** (optional) The maxPriorityFeePerGas (hexadecimal or number) to be used in this transaction, for use in EIP-1559 (type 2) transactions. */
    internal let maxPriorityFeePerGas: String?

    internal enum CodingKeys: String, CodingKey {
        case from
        case to
        case nonce
        case gasLimit = "gas_limit"
        case gasPrice = "gas_price"
        case data
        case value
        case chainId = "chain_id"
        case type
        case maxFeePerGas = "max_fee_per_gas"
        case maxPriorityFeePerGas = "max_priority_fee_per_gas"
    }
}

internal extension UnsignedEthereumTransaction {
    func toWalletApi() -> WalletApiUnsignedEthereumTransaction {
        WalletApiUnsignedEthereumTransaction(
            from: from,
            to: to,
            nonce: nonce?.hexString,
            gasLimit: gasLimit?.hexString,
            gasPrice: gasPrice?.hexString,
            data: data,
            value: value?.hexString,
            chainId: chainId?.number,
            type: type,
            maxFeePerGas: maxFeePerGas?.hexString,
            maxPriorityFeePerGas: maxPriorityFeePerGas?.hexString
        )
    }
}
