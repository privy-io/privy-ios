import CryptoKit
import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var hpkeEncryptor: Factory<HPKEEncryptor> {
        self { HPKEEncryptorImpl() }.shared
    }
}

/// The output of a single HPKE seal: what the recipient needs to open the ciphertext.
internal struct HPKESealedPayload: Sendable {
    /// The sender's encapsulated ephemeral public key, a 65-byte uncompressed P-256 point.
    internal let encapsulatedKey: Data

    /// The ciphertext, including the 16-byte authentication tag.
    internal let ciphertext: Data
}

/// Encrypts payloads with HPKE to a recipient P-256 public key, such as one published by the Privy
/// Wallet API.
internal protocol HPKEEncryptor: Sendable {
    /// Encrypts `plaintext` to the recipient's key with ``HPKE/Ciphersuite/privyWalletApi``, using a
    /// fresh sender context, an empty `info` and no additional authenticated data.
    ///
    /// - Parameters:
    ///   - plaintext: The data to encrypt.
    ///   - recipientPublicKey: The recipient's P-256 public key as a raw 65-byte uncompressed point
    ///     (`0x04 || X || Y`). SPKI DER keys are rejected.
    ///
    /// - Returns: The encapsulated key and ciphertext.
    ///
    /// - Throws: ``HPKEError/invalidRecipientPublicKey`` if the key is not an uncompressed point on
    ///   the curve, or a CryptoKit error if sealing fails.
    func seal(_ plaintext: Data, recipientPublicKey: Data) throws -> HPKESealedPayload
}

private final class HPKEEncryptorImpl: HPKEEncryptor {
    private static let uncompressedPointLength = 65
    private static let uncompressedPointPrefix: UInt8 = 0x04

    internal func seal(_ plaintext: Data, recipientPublicKey: Data) throws -> HPKESealedPayload {
        guard recipientPublicKey.count == Self.uncompressedPointLength,
              recipientPublicKey.first == Self.uncompressedPointPrefix,
              let publicKey = try? P256.KeyAgreement.PublicKey(x963Representation: recipientPublicKey)
        else {
            throw HPKEError.invalidRecipientPublicKey
        }

        var sender = try HPKE.Sender(recipientKey: publicKey, ciphersuite: .privyWalletApi, info: Data())
        let ciphertext = try sender.seal(plaintext)

        return HPKESealedPayload(encapsulatedKey: sender.encapsulatedKey, ciphertext: ciphertext)
    }
}
