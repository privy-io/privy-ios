import Foundation

extension Data {
    internal func base64UrlEncodedString() -> String {
        // Base64 encoded string that replaces the base64 characters
        // that are not allowed per the PKCE spec for ones that are
        return self
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    internal init?(base64URLEncoded string: String) {
        // Convert base64URL to base64
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        // Decode as standard base64
        self.init(base64Encoded: base64)
    }
}
