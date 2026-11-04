import Foundation
import CryptoKit
internal import FactoryKit

extension PrivyContainer {
    internal var pkceHelper: Factory<PKCEHelper> {
        self { PKCEHelperImpl() }.unique
    }
}

private final class PKCEHelperImpl: PKCEHelper {
    private enum Constants {
        static let CODE_VERIFIER_BYTE_LENGTH = 32
    }

    /**
     * As specified here: https://datatracker.ietf.org/doc/html/rfc7636#section-4.1
     * code_verifier = high-entropy cryptographic random STRING using the unreserved characters [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"
     * with a minimum length of 43 characters and a maximum length of 128 characters.
     *
     * 32 bytes gets us 256 bits, which results in 43 characters (6 bits per base64 character)
     * This is what is recommended in the spec.
     */
    func generateCodeVerifier() -> String {
        // Create random byte array of specified length
        var randomBytes = [UInt8](repeating: 0, count: Constants.CODE_VERIFIER_BYTE_LENGTH)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        if status == errSecSuccess {
            // Base 64 URL encoded string using random bytes generated, then replaced with valid characters
            let base64EncodedString = Data(randomBytes).base64UrlEncodedString()
            return base64EncodedString
        } else {
            // Fallback: returns empty string if secure random generation is unavailable
            return ""
        }
    }

    func generateStateCode() -> String {
        return generateCodeVerifier()
    }

    func deriveCodeChallenge(from codeVerifier: String) -> String {
        // UTF-8 encodes code verifier
        guard let codeVerifierData = codeVerifier.data(using: .utf8) else {
            // Handle error: Invalid code verifier
            return ""
        }

        // Create SHA 256 hash from encoded code verifier
        let digest = SHA256.hash(data: codeVerifierData)

        // Base 64 URL encode SHA 256 hash
        let base64EncodedHash = Data(digest).base64UrlEncodedString()

        return base64EncodedHash
    }
}
