import Foundation

/// A namespace for utilities provided by Privy
public struct Utils {
    /// Convert a value to a hex string, supports Int or String argument
    public static func toHexString(_ value: Any) -> String? {
        if let intValue = value as? Int {
            return String(format: "0x%02X", intValue)
        } else if let dblValue = value as? Double {
            return String(format: "0x%02X", dblValue)
        } else if let decimalValue = value as? Decimal {
            return String(format: "0x%02X", decimalValue as CVarArg)
        } else if let hexString = value as? String {
            return hexString.hasPrefix("0x") ? hexString : "0x" + hexString
        } else {
            // Unsupported type
            return nil
        }
    }
}
