import Foundation

/// A wrapper type for binary data that is encoded as a standard base64 string, with padding
internal struct Base64Data: Codable, Equatable, Sendable {
    internal let data: Data

    internal init(_ data: Data) {
        self.data = data
    }

    internal init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let base64String = try container.decode(String.self)

        // The message doesn't include the string, which may not be safe to log
        guard let data = Data(base64Encoded: base64String) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "The string is not valid base64.")
        }
        self.data = data
    }

    internal func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data.base64EncodedString())
    }
}
