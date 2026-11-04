internal struct WalletApiCAIP2: Codable {
    private let string: String

    internal init?(string: String) {
        // regex from the spec https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-2.md#specification
        let regex = /^[-a-z0-9]{3,8}:[-_a-zA-Z0-9]{1,32}$/

        if string.wholeMatch(of: regex) == nil {
            return nil
        }

        self.string = string
    }

    internal init(eip155: Int) {
        // Force unwrapping is safe because we know this will always be a valid CAIP2-formatted string
        self.init(string: "eip155:\(String(eip155))")!
    }

    internal init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let caip2 = WalletApiCAIP2(string: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Chain ID must be a valid CAIP-2 chain ID, e.g. 'eip155:1'"
            )
        }

        self = caip2
    }

    internal func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }
}
