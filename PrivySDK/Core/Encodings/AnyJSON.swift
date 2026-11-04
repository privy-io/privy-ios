import Foundation

/// A Codable container for arbitrary JSON values (object, array, string, number, bool, null).
///
/// Used where a field's schema is unknown at compile time, such as EIP-712 `domain`
/// and `message` payloads which are `Record<string, any>` in the Ethereum spec.
///
/// Numbers are decoded with exact integer preservation:
/// - Integers that fit in `Int64` → `.integer`
/// - Non-negative integers that fit in `UInt64` but not `Int64` → `.unsignedInteger`
/// - All other numbers (fractions, out-of-range) → `.number` (Double)
///
/// This prevents precision loss on EIP-712 values such as large nonces, token amounts,
/// and chain IDs where `Double` cannot exactly represent integers > 2^53.
internal enum AnyJSON: Codable, Equatable {
    case object([String: AnyJSON])
    case array([AnyJSON])
    case string(String)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case number(Double)
    case bool(Bool)
    case null

    internal init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int64.self) {
            self = .integer(int)
        } else if let uint = try? container.decode(UInt64.self) {
            self = .unsignedInteger(uint)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyJSON].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyJSON].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyJSON: unsupported JSON value"
            )
        }
    }

    internal func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .unsignedInteger(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}
