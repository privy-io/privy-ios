import Foundation

/// Errors thrown by ``HPKEEncryptor`` and ``HPKEDecryptor`` before or after the CryptoKit HPKE
/// operation itself.
internal enum HPKEError: LocalizedError {
    /// A base64 input could not be decoded. The associated value names the field.
    case invalidBase64(String)

    /// The decrypted plaintext is not valid UTF-8.
    case invalidDecryptedData

    /// The recipient public key is not a raw 65-byte uncompressed P-256 point on the curve.
    case invalidRecipientPublicKey

    internal var errorDescription: String? {
        switch self {
        case .invalidBase64(let field):
            return "Invalid base64 encoding for HPKE field: \(field)"
        case .invalidDecryptedData:
            return "Decrypted HPKE data is not valid UTF-8"
        case .invalidRecipientPublicKey:
            return "HPKE recipient public key is not an uncompressed P-256 point"
        }
    }
}
