import Foundation

extension EthereumRpcRequest {
    public struct EIP712TypedData: Sendable, Encodable {
        public let domain: EIP712Domain
        public let primaryType: String
        public let types: [String: [EIP712Type]]
        /// The structured data to sign, as defined by `primaryType` in the `types` map.
        /// Must be JSON-encodable with finite nesting depth — excessively deep or large
        /// structures will exhaust the call stack during encoding.
        public let message: any Sendable & Encodable

        public init(domain: EIP712Domain, primaryType: String, types: [String: [EIP712Type]], message: any Sendable & Encodable) {
            self.domain = domain
            self.primaryType = primaryType
            self.types = types
            self.message = message
        }

        public struct EIP712Type: Sendable, Encodable {
            public let name: String
            public let type: String

            public init(_ name: String, type: String) {
                self.name = name
                self.type = type
            }
        }

        public struct EIP712Domain: Sendable, Encodable {
            public let name: String?
            public let version: String?
            public let chainId: Int?
            public let verifyingContract: String?
            public let salt: Data?

            public init(
                name: String? = nil,
                version: String? = nil,
                chainId: Int? = nil,
                verifyingContract: String? = nil,
                salt: Data? = nil
            ) {
                self.name = name
                self.version = version
                self.chainId = chainId
                self.verifyingContract = verifyingContract
                self.salt = salt
            }
        }

        internal enum EncodingKeys: String, CodingKey {
            case domain
            case types
            case message
            case primaryType
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: EncodingKeys.self)
            try container.encode(self.domain, forKey: EncodingKeys.domain)
            try container.encode(self.types, forKey: EncodingKeys.types)
            try container.encode(self.message, forKey: EncodingKeys.message)
            try container.encode(self.primaryType, forKey: EncodingKeys.primaryType)
        }
    }
}
