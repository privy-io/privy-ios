//

import Foundation

internal extension String {
    /// Decodes base64url encoded data
    func base64UrlDecodedData() -> Data? {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        while base64.count % 4 != 0 {
            base64 += "="
        }

        return Data(base64Encoded: base64)
    }

    /// Indicates if the string is a valid "hex encoding", by starting with the `0x` sequence and following that with "hex digits" only (0-9 and A-F, case insensitive)
    var isHexEncoded: Bool {
        self.starts(with: "0x") && self.dropFirst(2).allSatisfy { $0.isHexDigit }
    }
}
