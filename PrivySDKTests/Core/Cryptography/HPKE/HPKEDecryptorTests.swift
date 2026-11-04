import CryptoKit
import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Tests ``HPKEDecryptor`` against an independent baseline sender (CryptoKit's `HPKE.Sender` with
/// the same ciphersuite, empty `info` and no AAD) and against the RFC 9180 known-answer vectors for
/// ``HPKE/Ciphersuite/privyWalletApi``.
///
/// The decryptor fixes `info` and AAD to empty, while every RFC 9180 vector uses a non-empty `info`
/// and AAD, so the vector ciphertexts can't be fed through `decrypt` itself. The known-answer tests
/// instead pin the shared ciphersuite (and CryptoKit's implementation of it) that `decrypt` opens
/// with, and the decryptor is separately run with the RFC 9180 recipient key.
internal final class HPKEDecryptorTests: PrivyTestCase {
    private var decryptor: HPKEDecryptor!

    override internal func setUp() {
        super.setUp()
        decryptor = resolve(\PrivyContainer.hpkeDecryptor)
    }

    // MARK: - RFC 9180 known-answer vectors

    internal func testRFC9180RecipientPublicKeyMatchesItsPrivateKey() throws {
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: RFC9180Vectors.recipientPrivateKey)

        XCTAssertEqual(privateKey.publicKey.x963Representation, RFC9180Vectors.recipientPublicKey)
    }

    internal func testCiphersuiteOpensRFC9180Encryptions() throws {
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: RFC9180Vectors.recipientPrivateKey)
        var recipient = try HPKE.Recipient(
            privateKey: privateKey,
            ciphersuite: .privyWalletApi,
            info: RFC9180Vectors.info,
            encapsulatedKey: RFC9180Vectors.encapsulatedKey
        )

        for encryption in RFC9180Vectors.encryptions {
            let plaintext = try recipient.open(encryption.ciphertext, authenticating: encryption.aad)

            XCTAssertEqual(
                String(data: plaintext, encoding: .utf8),
                RFC9180Vectors.plaintext,
                "sequence number \(encryption.sequenceNumber)"
            )
        }
    }

    internal func testCiphersuiteDerivesRFC9180ExportedValues() throws {
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: RFC9180Vectors.recipientPrivateKey)
        let recipient = try HPKE.Recipient(
            privateKey: privateKey,
            ciphersuite: .privyWalletApi,
            info: RFC9180Vectors.info,
            encapsulatedKey: RFC9180Vectors.encapsulatedKey
        )

        for export in RFC9180Vectors.exports {
            let secret = try recipient.exportSecret(context: export.context, outputByteCount: 32)

            XCTAssertEqual(secret.withUnsafeBytes { Data($0) }, export.value, "exporter context \(export.context)")
        }
    }

    internal func testCiphersuiteRejectsRFC9180EncryptionOutOfSequence() throws {
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: RFC9180Vectors.recipientPrivateKey)
        var recipient = try HPKE.Recipient(
            privateKey: privateKey,
            ciphersuite: .privyWalletApi,
            info: RFC9180Vectors.info,
            encapsulatedKey: RFC9180Vectors.encapsulatedKey
        )
        let second = RFC9180Vectors.encryptions[1]

        XCTAssertThrowsError(try recipient.open(second.ciphertext, authenticating: second.aad))
    }

    internal func testDecryptorRejectsRFC9180EncryptionBecauseItUsesAnEmptyInfo() throws {
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: RFC9180Vectors.recipientPrivateKey)
        let first = RFC9180Vectors.encryptions[0]

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: first.ciphertext.base64EncodedString(),
            encapsulatedKey: RFC9180Vectors.encapsulatedKey.base64EncodedString(),
            privateKey: privateKey
        )) { error in
            HPKETestFixtures.assertCryptoKitError(error)
        }
    }

    internal func testDecryptsWithTheRFC9180RecipientKey() throws {
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: RFC9180Vectors.recipientPrivateKey)
        let publicKey = try P256.KeyAgreement.PublicKey(x963Representation: RFC9180Vectors.recipientPublicKey)
        let sealed = try HPKETestFixtures.baselineSeal(Data(RFC9180Vectors.plaintext.utf8), to: publicKey)

        let decrypted = try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: privateKey
        )

        XCTAssertEqual(decrypted, RFC9180Vectors.plaintext)
    }

    // MARK: - Ephemeral key pair

    internal func testEphemeralPublicKeyIsBase64SpkiOfThePrivateKey() throws {
        let keypair = try decryptor.generateEphemeralKeypair()

        let spki = try XCTUnwrap(Data(base64Encoded: keypair.publicKeyBase64SPKI))
        let publicKey = try P256.KeyAgreement.PublicKey(derRepresentation: spki)

        XCTAssertEqual(spki.count, 91)
        XCTAssertEqual(publicKey.x963Representation, keypair.privateKey.publicKey.x963Representation)
    }

    internal func testEachEphemeralKeypairIsFresh() throws {
        var publicKeys = Set<String>()
        for _ in 0 ..< 10 {
            publicKeys.insert(try decryptor.generateEphemeralKeypair().publicKeyBase64SPKI)
        }

        XCTAssertEqual(publicKeys.count, 10)
    }

    // MARK: - Decrypts messages from a baseline sender

    internal func testDecryptsAMessageFromABaselineSender() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello, privy".utf8), to: try Self.publicKey(of: keypair))

        let decrypted = try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: keypair.privateKey
        )

        XCTAssertEqual(decrypted, "hello, privy")
    }

    /// Mirrors `/wallets/authenticate`: the API seals a base64 PKCS#8 P-256 signing key to the
    /// ephemeral SPKI key, and the SDK decrypts it into a key it can sign with.
    internal func testDecryptsAnAuthorizationKeyPayload() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let authorizationKey = P256.Signing.PrivateKey()
        let payload = authorizationKey.derRepresentation.base64EncodedString()
        let sealed = try HPKETestFixtures.baselineSeal(Data(payload.utf8), to: try Self.publicKey(of: keypair))

        let decrypted = try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: keypair.privateKey
        )
        let keyData = try XCTUnwrap(Data(base64Encoded: decrypted))
        let decryptedKey = try P256.Signing.PrivateKey(derRepresentation: keyData)

        XCTAssertEqual(decrypted, payload)
        XCTAssertEqual(decryptedKey.publicKey.x963Representation, authorizationKey.publicKey.x963Representation)
    }

    internal func testDecryptsAnEmptyMessage() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data(), to: try Self.publicKey(of: keypair))

        let decrypted = try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: keypair.privateKey
        )

        XCTAssertEqual(decrypted, "")
    }

    internal func testDecryptsMultibyteUTF8() throws {
        let message = "Héllo, wörld — 你好 🔐"
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data(message.utf8), to: try Self.publicKey(of: keypair))

        let decrypted = try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: keypair.privateKey
        )

        XCTAssertEqual(decrypted, message)
    }

    internal func testDecryptsALargeMessage() throws {
        let message = HPKETestFixtures.asciiString(byteCount: 1 << 20)
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data(message.utf8), to: try Self.publicKey(of: keypair))

        let decrypted = try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: keypair.privateKey
        )

        XCTAssertEqual(decrypted, message)
    }

    internal func testDecryptsManyMessagesToTheSameKeypair() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let publicKey = try Self.publicKey(of: keypair)

        for index in 0 ..< 10 {
            let message = "message \(index)"
            let sealed = try HPKETestFixtures.baselineSeal(Data(message.utf8), to: publicKey)

            let decrypted = try decryptor.decrypt(
                ciphertext: sealed.ciphertext,
                encapsulatedKey: sealed.encapsulatedKey,
                privateKey: keypair.privateKey
            )

            XCTAssertEqual(decrypted, message)
        }
    }

    // MARK: - Malformed input

    internal func testRejectsInvalidBase64Ciphertext() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello".utf8), to: try Self.publicKey(of: keypair))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: "not base64!",
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: keypair.privateKey
        )) { error in
            HPKETestFixtures.assertInvalidBase64(error, field: "ciphertext")
        }
    }

    internal func testRejectsInvalidBase64EncapsulatedKey() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello".utf8), to: try Self.publicKey(of: keypair))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: "not base64!",
            privateKey: keypair.privateKey
        )) { error in
            HPKETestFixtures.assertInvalidBase64(error, field: "encapsulated_key")
        }
    }

    internal func testReportsTheCiphertextFirstWhenBothFieldsAreInvalidBase64() throws {
        let keypair = try decryptor.generateEphemeralKeypair()

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: "%%%",
            encapsulatedKey: "%%%",
            privateKey: keypair.privateKey
        )) { error in
            HPKETestFixtures.assertInvalidBase64(error, field: "ciphertext")
        }
    }

    internal func testRejectsTruncatedCiphertexts() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello, privy".utf8), to: try Self.publicKey(of: keypair))
        let ciphertext = try XCTUnwrap(Data(base64Encoded: sealed.ciphertext))

        for length in [0, 1, HPKETestFixtures.tagLength - 1, HPKETestFixtures.tagLength, ciphertext.count - 1] {
            XCTAssertThrowsError(try decryptor.decrypt(
                ciphertext: Data(ciphertext.prefix(length)).base64EncodedString(),
                encapsulatedKey: sealed.encapsulatedKey,
                privateKey: keypair.privateKey
            ), "length \(length)") { error in
                HPKETestFixtures.assertCryptoKitError(error)
            }
        }
    }

    internal func testRejectsATamperedCiphertext() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello, privy".utf8), to: try Self.publicKey(of: keypair))
        let ciphertext = try XCTUnwrap(Data(base64Encoded: sealed.ciphertext))

        for offset in [0, ciphertext.count / 2, ciphertext.count - 1] {
            let tampered = HPKETestFixtures.flippingBit(in: ciphertext, atOffset: offset)

            XCTAssertThrowsError(try decryptor.decrypt(
                ciphertext: tampered.base64EncodedString(),
                encapsulatedKey: sealed.encapsulatedKey,
                privateKey: keypair.privateKey
            ), "offset \(offset)") { error in
                HPKETestFixtures.assertCryptoKitError(error)
            }
        }
    }

    internal func testRejectsATamperedEncapsulatedKey() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello, privy".utf8), to: try Self.publicKey(of: keypair))
        let encapsulatedKey = try XCTUnwrap(Data(base64Encoded: sealed.encapsulatedKey))

        for offset in [0, 1, HPKETestFixtures.uncompressedPointLength - 1] {
            let tampered = HPKETestFixtures.flippingBit(in: encapsulatedKey, atOffset: offset)

            XCTAssertThrowsError(try decryptor.decrypt(
                ciphertext: sealed.ciphertext,
                encapsulatedKey: tampered.base64EncodedString(),
                privateKey: keypair.privateKey
            ), "offset \(offset)") { error in
                HPKETestFixtures.assertCryptoKitError(error)
            }
        }
    }

    internal func testRejectsAnEncapsulatedKeyFromADifferentSender() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello, privy".utf8), to: try Self.publicKey(of: keypair))
        let other = try HPKETestFixtures.baselineSeal(Data("hello, privy".utf8), to: try Self.publicKey(of: keypair))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: other.encapsulatedKey,
            privateKey: keypair.privateKey
        )) { error in
            HPKETestFixtures.assertCryptoKitError(error)
        }
    }

    internal func testRejectsMalformedEncapsulatedKeys() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello, privy".utf8), to: try Self.publicKey(of: keypair))
        let encapsulatedKey = try P256.KeyAgreement.PublicKey(
            x963Representation: try XCTUnwrap(Data(base64Encoded: sealed.encapsulatedKey))
        )
        let malformed: [String: Data] = [
            "empty": Data(),
            "truncated": Data(encapsulatedKey.x963Representation.dropLast()),
            "extended": encapsulatedKey.x963Representation + Data([0x00]),
            "compressed": encapsulatedKey.compressedRepresentation,
            "spki": encapsulatedKey.derRepresentation,
            "off-curve": Data([0x04] + [UInt8](repeating: 0x01, count: 64)),
        ]

        for (name, encapsulatedKey) in malformed {
            XCTAssertThrowsError(try decryptor.decrypt(
                ciphertext: sealed.ciphertext,
                encapsulatedKey: encapsulatedKey.base64EncodedString(),
                privateKey: keypair.privateKey
            ), name) { error in
                HPKETestFixtures.assertCryptoKitError(error)
            }
        }
    }

    internal func testRejectsAMessageForADifferentKeypair() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let otherKeypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data("hello, privy".utf8), to: try Self.publicKey(of: otherKeypair))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: keypair.privateKey
        )) { error in
            HPKETestFixtures.assertCryptoKitError(error)
        }
    }

    internal func testRejectsAMessageSealedWithANonEmptyInfo() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        var sender = try HPKE.Sender(
            recipientKey: try Self.publicKey(of: keypair),
            ciphersuite: .privyWalletApi,
            info: RFC9180Vectors.info
        )
        let ciphertext = try sender.seal(Data("hello, privy".utf8))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: ciphertext.base64EncodedString(),
            encapsulatedKey: sender.encapsulatedKey.base64EncodedString(),
            privateKey: keypair.privateKey
        )) { error in
            HPKETestFixtures.assertCryptoKitError(error)
        }
    }

    internal func testRejectsAMessageSealedWithAdditionalAuthenticatedData() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        var sender = try HPKE.Sender(recipientKey: try Self.publicKey(of: keypair), ciphersuite: .privyWalletApi, info: Data())
        let ciphertext = try sender.seal(Data("hello, privy".utf8), authenticating: Data("Count-0".utf8))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: ciphertext.base64EncodedString(),
            encapsulatedKey: sender.encapsulatedKey.base64EncodedString(),
            privateKey: keypair.privateKey
        )) { error in
            HPKETestFixtures.assertCryptoKitError(error)
        }
    }

    internal func testRejectsAMessageSealedWithAESGCM() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        var sender = try HPKE.Sender(
            recipientKey: try Self.publicKey(of: keypair),
            ciphersuite: HPKE.Ciphersuite(kem: .P256_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .AES_GCM_256),
            info: Data()
        )
        let ciphertext = try sender.seal(Data("hello, privy".utf8))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: ciphertext.base64EncodedString(),
            encapsulatedKey: sender.encapsulatedKey.base64EncodedString(),
            privateKey: keypair.privateKey
        )) { error in
            HPKETestFixtures.assertCryptoKitError(error)
        }
    }

    internal func testRejectsANonUTF8Plaintext() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try HPKETestFixtures.baselineSeal(Data([0xFF, 0xFE, 0xC3, 0x28]), to: try Self.publicKey(of: keypair))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: keypair.privateKey
        )) { error in
            guard case .invalidDecryptedData? = error as? HPKEError else {
                return XCTFail("Expected HPKEError.invalidDecryptedData, got \(error)")
            }
        }
    }

    // MARK: - Helpers

    /// Parses the ephemeral key pair's SPKI public key, as the Privy Wallet API does.
    private static func publicKey(of keypair: HPKEEphemeralKeypair) throws -> P256.KeyAgreement.PublicKey {
        let spki = try XCTUnwrap(Data(base64Encoded: keypair.publicKeyBase64SPKI))
        return try P256.KeyAgreement.PublicKey(derRepresentation: spki)
    }
}
