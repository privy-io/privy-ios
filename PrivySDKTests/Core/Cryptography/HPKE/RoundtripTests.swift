import CryptoKit
import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Tests ``HPKEEncryptor`` and ``HPKEDecryptor`` together: whatever the encryptor seals to the
/// decryptor's ephemeral public key, the decryptor opens.
internal final class HPKERoundtripTests: PrivyTestCase {
    private var encryptor: HPKEEncryptor!
    private var decryptor: HPKEDecryptor!

    override internal func setUp() {
        super.setUp()
        encryptor = resolve(\PrivyContainer.hpkeEncryptor)
        decryptor = resolve(\PrivyContainer.hpkeDecryptor)
    }

    internal func testRoundtripsAcrossPlaintextSizes() throws {
        let sizes = [0, 1, 2, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129, 255, 256, 257, 1023, 1024, 4096, 65536]

        for size in sizes {
            let message = HPKETestFixtures.asciiString(byteCount: size)

            XCTAssertEqual(try roundtrip(message), message, "size \(size)")
        }
    }

    internal func testRoundtripsALargePlaintext() throws {
        let message = HPKETestFixtures.asciiString(byteCount: 1 << 20)

        XCTAssertEqual(try roundtrip(message), message)
    }

    internal func testRoundtripsMultibyteUTF8() throws {
        for message in ["é", "你好", "🔐", "Héllo, wörld — 你好 🔐", String(repeating: "🔑", count: 1000)] {
            XCTAssertEqual(try roundtrip(message), message)
        }
    }

    internal func testRoundtripsRandomPayloadsRepeatedly() throws {
        for iteration in 0 ..< 50 {
            let message = HPKETestFixtures.randomBytes(Int.random(in: 0 ... 2048)).base64EncodedString()

            XCTAssertEqual(try roundtrip(message), message, "iteration \(iteration)")
        }
    }

    internal func testRoundtripsAnAuthorizationKeyPayload() throws {
        let authorizationKey = P256.Signing.PrivateKey()
        let message = authorizationKey.derRepresentation.base64EncodedString()

        let decrypted = try roundtrip(message)
        let keyData = try XCTUnwrap(Data(base64Encoded: decrypted))
        let decryptedKey = try P256.Signing.PrivateKey(derRepresentation: keyData)

        XCTAssertEqual(decryptedKey.publicKey.x963Representation, authorizationKey.publicKey.x963Representation)
    }

    internal func testRoundtripsManyMessagesToTheSameKeypair() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let recipientPublicKey = try Self.rawPublicKey(of: keypair)

        for index in 0 ..< 20 {
            let message = "message \(index)"
            let sealed = try encryptor.seal(Data(message.utf8), recipientPublicKey: recipientPublicKey)

            let decrypted = try decryptor.decrypt(
                ciphertext: sealed.ciphertext.base64EncodedString(),
                encapsulatedKey: sealed.encapsulatedKey.base64EncodedString(),
                privateKey: keypair.privateKey
            )

            XCTAssertEqual(decrypted, message)
        }
    }

    internal func testRoundtripsWithTheRFC9180RecipientKeyPair() throws {
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: RFC9180Vectors.recipientPrivateKey)
        let sealed = try encryptor.seal(
            Data(RFC9180Vectors.plaintext.utf8),
            recipientPublicKey: RFC9180Vectors.recipientPublicKey
        )

        let decrypted = try decryptor.decrypt(
            ciphertext: sealed.ciphertext.base64EncodedString(),
            encapsulatedKey: sealed.encapsulatedKey.base64EncodedString(),
            privateKey: privateKey
        )

        XCTAssertEqual(decrypted, RFC9180Vectors.plaintext)
    }

    internal func testDoesNotOpenAPayloadSealedToADifferentKeypair() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let otherKeypair = try decryptor.generateEphemeralKeypair()
        let sealed = try encryptor.seal(Data("hello".utf8), recipientPublicKey: try Self.rawPublicKey(of: otherKeypair))

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: sealed.ciphertext.base64EncodedString(),
            encapsulatedKey: sealed.encapsulatedKey.base64EncodedString(),
            privateKey: keypair.privateKey
        ))
    }

    internal func testDoesNotOpenAPayloadWithSwappedEncapsulatedKeys() throws {
        let keypair = try decryptor.generateEphemeralKeypair()
        let recipientPublicKey = try Self.rawPublicKey(of: keypair)
        let first = try encryptor.seal(Data("first".utf8), recipientPublicKey: recipientPublicKey)
        let second = try encryptor.seal(Data("second".utf8), recipientPublicKey: recipientPublicKey)

        XCTAssertThrowsError(try decryptor.decrypt(
            ciphertext: first.ciphertext.base64EncodedString(),
            encapsulatedKey: second.encapsulatedKey.base64EncodedString(),
            privateKey: keypair.privateKey
        ))
    }

    // MARK: - Helpers

    /// Seals `message` with the encryptor to a fresh decryptor key pair, then decrypts it.
    private func roundtrip(_ message: String) throws -> String {
        let keypair = try decryptor.generateEphemeralKeypair()
        let sealed = try encryptor.seal(Data(message.utf8), recipientPublicKey: try Self.rawPublicKey(of: keypair))

        return try decryptor.decrypt(
            ciphertext: sealed.ciphertext.base64EncodedString(),
            encapsulatedKey: sealed.encapsulatedKey.base64EncodedString(),
            privateKey: keypair.privateKey
        )
    }

    /// Converts the decryptor's base64 SPKI public key into the raw uncompressed point the encryptor
    /// takes.
    private static func rawPublicKey(of keypair: HPKEEphemeralKeypair) throws -> Data {
        let spki = try XCTUnwrap(Data(base64Encoded: keypair.publicKeyBase64SPKI))
        return try P256.KeyAgreement.PublicKey(derRepresentation: spki).x963Representation
    }
}
