// eth_signTypedDataV4 ethereum RPC

internal struct WalletApiEthereumSignTypedDataV4RpcParams: Encodable {
    internal let typedData: EthereumTypedDataV4

    // This struct needs to be Codable (not Encodable only),
    // because we are decoding the *arbitrary* JSON string passed in
    internal struct EthereumTypedDataV4: Codable {
        internal let domain: AnyJSON // Record<string, any>
        internal let types: TypedDataTypes
        internal let message: AnyJSON // Record<string, any>
        internal let primaryType: String

        internal typealias TypedDataTypes = [String: [DomainType]]

        internal struct DomainType: Codable {
            internal let name: String
            internal let type: String
        }

        internal enum DecodingKeys: String, CodingKey {
            case domain
            case types
            case message
            case primaryType
        }

        internal init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: DecodingKeys.self)
            self.domain = try container.decode(AnyJSON.self, forKey: DecodingKeys.domain)
            self.types = try container.decode(TypedDataTypes.self, forKey: DecodingKeys.types)
            self.message = try container.decode(AnyJSON.self, forKey: DecodingKeys.message)
            self.primaryType = try container.decode(String.self, forKey: DecodingKeys.primaryType)
        }

        internal enum EncodingKeys: String, CodingKey {
            case domain
            case types
            case message
            case primaryType = "primary_type"
        }

        internal func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: EncodingKeys.self)
            try container.encode(self.domain, forKey: EncodingKeys.domain)
            try container.encode(self.types, forKey: EncodingKeys.types)
            try container.encode(self.message, forKey: EncodingKeys.message)
            try container.encode(self.primaryType, forKey: EncodingKeys.primaryType)
        }
    }

    internal enum CodingKeys: String, CodingKey {
        case typedData = "typed_data"
    }

    internal func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.typedData, forKey: .typedData)
    }
}

internal struct WalletApiEthereumSignTypedDataV4RpcResponse: Decodable {
    /// Signature produced by the wallet
    internal let signature: String
}
