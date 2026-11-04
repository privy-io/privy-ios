import Foundation

public extension EthereumRpcRequest {
    struct UnsignedEthTransaction: Sendable, Encodable {
        public enum Quantity {
            case int(Int)
            case hexadecimalNumber(String)

            internal var hexString: String {
                switch self {
                case let .int(number):
                    String(format: "0x%02X", number)
                case let .hexadecimalNumber(hexString):
                    hexString
                }
            }
        }

        public typealias Address = String
        public typealias HexQuantity = String
        public typealias EIP2718TransactionType = Int

        internal let from: Address?
        internal let to: Address?
        internal let nonce: HexQuantity?
        internal let gasLimit: HexQuantity?
        internal let gasPrice: HexQuantity?
        internal let data: String?
        internal let value: HexQuantity?
        internal let chainId: HexQuantity?
        internal let type: EIP2718TransactionType?
        internal let maxFeePerGas: HexQuantity?
        internal let maxPriorityFeePerGas: HexQuantity?

        public init(
            from: Address? = nil,
            to: Address? = nil,
            nonce: Quantity? = nil,
            gasLimit: Quantity? = nil,
            gasPrice: Quantity? = nil,
            data: String? = nil,
            value: Quantity? = nil,
            chainId: Quantity? = nil,
            type: EIP2718TransactionType? = nil,
            maxFeePerGas: Quantity? = nil,
            maxPriorityFeePerGas: Quantity? = nil
        ) {
            self.from = from
            self.to = to
            self.nonce = nonce?.hexString
            self.gasLimit = gasLimit?.hexString
            self.gasPrice = gasPrice?.hexString
            self.data = data
            self.value = value?.hexString
            self.chainId = chainId?.hexString
            self.type = type
            self.maxFeePerGas = maxFeePerGas?.hexString
            self.maxPriorityFeePerGas = maxPriorityFeePerGas?.hexString
        }
    }
}
