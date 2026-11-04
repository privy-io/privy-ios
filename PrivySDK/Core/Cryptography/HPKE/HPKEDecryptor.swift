import CryptoKit
import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var hpkeDecryptor: Factory<HPKEDecryptor> {
        self { HPKEDecryptorImpl() }.shared
    }
}

/// A P-256 key pair generated to receive a single HPKE-encrypted payload.
internal struct HPKEEphemeralKeypair: Sendable {
    /// The private key used to open the payload.
    internal let privateKey: P256.KeyAgreement.PrivateKey

    /// The public key as base64-encoded SPKI DER, the form sent to the Privy Wallet API.
    internal let publicKeyBase64SPKI: String
}

/// Opens payloads that the Privy Wallet API encrypted to a key pair the SDK generated, using
/// ``HPKE/Ciphersuite/privyWalletApi`` in base mode with an empty `info` and no additional
/// authenticated data.
internal protocol HPKEDecryptor: Sendable {
    /// Generates a fresh P-256 key pair to receive an HPKE-encrypted payload.
    ///
    /// - Returns: The key pair, with the public key encoded as base64 SPKI DER.
    ///
    /// - Throws: An error if the key pair cannot be generated.
    func generateEphemeralKeypair() throws -> HPKEEphemeralKeypair

    /// Decrypts an HPKE payload sealed to `privateKey`'s public key and decodes it as UTF-8.
    ///
    /// - Parameters:
    ///   - ciphertextBase64: The base64-encoded ciphertext, including the 16-byte authentication tag.
    ///   - encapsulatedKeyBase64: The base64-encoded encapsulated key, a 65-byte uncompressed P-256 point.
    ///   - privateKey: The recipient's private key, usually from ``generateEphemeralKeypair()``.
    ///
    /// - Returns: The decrypted plaintext as a UTF-8 string.
    ///
    /// - Throws: ``HPKEError/invalidBase64(_:)`` if either input is not valid base64,
    ///   ``HPKEError/invalidDecryptedData`` if the plaintext is not valid UTF-8, or a CryptoKit error
    ///   if the encapsulated key is malformed or the ciphertext fails authentication.
    func decrypt(
        ciphertext ciphertextBase64: String,
        encapsulatedKey encapsulatedKeyBase64: String,
        privateKey: P256.KeyAgreement.PrivateKey
    ) throws -> String
}

private final class HPKEDecryptorImpl: HPKEDecryptor {
    internal func generateEphemeralKeypair() throws -> HPKEEphemeralKeypair {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let spkiData = privateKey.publicKey.derRepresentation
        let publicKeyBase64 = spkiData.base64EncodedString()
        return HPKEEphemeralKeypair(
            privateKey: privateKey,
            publicKeyBase64SPKI: publicKeyBase64
        )
    }

    internal func decrypt(
        ciphertext ciphertextBase64: String,
        encapsulatedKey encapsulatedKeyBase64: String,
        privateKey: P256.KeyAgreement.PrivateKey
    ) throws -> String {
        guard let ciphertextData = Data(base64Encoded: ciphertextBase64) else {
            throw HPKEError.invalidBase64("ciphertext")
        }

        guard let encapsulatedKeyData = Data(base64Encoded: encapsulatedKeyBase64) else {
            throw HPKEError.invalidBase64("encapsulated_key")
        }

        var recipient = try HPKE.Recipient(
            privateKey: privateKey,
            ciphersuite: .privyWalletApi,
            info: Data(),
            encapsulatedKey: encapsulatedKeyData
        )

        let plaintext = try recipient.open(ciphertextData)

        guard let result = String(data: plaintext, encoding: .utf8) else {
            throw HPKEError.invalidDecryptedData
        }

        return result
    }
}
