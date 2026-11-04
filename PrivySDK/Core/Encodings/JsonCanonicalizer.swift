import Foundation

/// A utility class to canonicalize JSON objects (RFC 8785-style).
internal final class JsonCanonicalizer {
    private let jsonEncoder: JSONEncoder

    internal init() {
        let outputFormatting = JSONEncoder.OutputFormatting(arrayLiteral: [
            .sortedKeys,
            .withoutEscapingSlashes,
        ])
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = outputFormatting
        self.jsonEncoder = jsonEncoder
    }

    internal func encode<T>(_ value: T) throws -> Data where T: Encodable {
        return try jsonEncoder.encode(value)
    }
}
