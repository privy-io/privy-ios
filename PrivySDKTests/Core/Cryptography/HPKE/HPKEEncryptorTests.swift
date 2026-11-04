import CryptoKit
import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Tests ``HPKEEncryptor`` against an independent baseline recipient (CryptoKit's `HPKE.Recipient`
/// with the same ciphersuite, empty `info` and no AAD).
///
/// CryptoKit's `HPKE.Sender` generates its ephemeral key internally and doesn't let callers inject
/// one, so the RFC 9180 sender known-answer ciphertexts can't be reproduced. Instead these tests
/// check that whatever the encryptor produces opens with a baseline recipient, including the
/// RFC 9180 A.5.1 recipient key pair.
internal final class HPKEEncryptorTests: PrivyTestCase {
    private var encryptor: HPKEEncryptor!

    override internal func setUp() {
        super.setUp()
        encryptor = resolve(\PrivyContainer.hpkeEncryptor)
    }

    // MARK: - Opens with a baseline recipient

    internal func testSealedPayloadOpensWithABaselineRecipient() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let plaintext = HPKETestFixtures.randomBytes(32)

        let sealed = try encryptor.seal(plaintext, recipientPublicKey: recipientKey.publicKey.x963Representation)
        let opened = try HPKETestFixtures.baselineOpen(
            sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: recipientKey
        )

        XCTAssertEqual(opened, plaintext)
    }

    internal func testSealedPayloadOpensWithTheRFC9180RecipientKeyPair() throws {
        let recipientKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: RFC9180Vectors.recipientPrivateKey)
        let plaintext = Data(RFC9180Vectors.plaintext.utf8)

        let sealed = try encryptor.seal(plaintext, recipientPublicKey: RFC9180Vectors.recipientPublicKey)
        let opened = try HPKETestFixtures.baselineOpen(
            sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: recipientKey
        )

        XCTAssertEqual(opened, plaintext)
    }

    internal func testSealedPayloadOpensForManyRecipients() throws {
        for _ in 0 ..< 20 {
            let recipientKey = P256.KeyAgreement.PrivateKey()
            let plaintext = HPKETestFixtures.randomBytes(Int.random(in: 0 ... 512))

            let sealed = try encryptor.seal(plaintext, recipientPublicKey: recipientKey.publicKey.x963Representation)
            let opened = try HPKETestFixtures.baselineOpen(
                sealed.ciphertext,
                encapsulatedKey: sealed.encapsulatedKey,
                privateKey: recipientKey
            )

            XCTAssertEqual(opened, plaintext)
        }
    }

    internal func testSealsAnEmptyPlaintext() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()

        let sealed = try encryptor.seal(Data(), recipientPublicKey: recipientKey.publicKey.x963Representation)
        let opened = try HPKETestFixtures.baselineOpen(
            sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: recipientKey
        )

        XCTAssertTrue(opened.isEmpty)
        XCTAssertEqual(sealed.ciphertext.count, HPKETestFixtures.tagLength)
    }

    internal func testSealsALargePlaintext() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let plaintext = HPKETestFixtures.randomBytes(1 << 20)

        let sealed = try encryptor.seal(plaintext, recipientPublicKey: recipientKey.publicKey.x963Representation)
        let opened = try HPKETestFixtures.baselineOpen(
            sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: recipientKey
        )

        XCTAssertEqual(opened, plaintext)
        XCTAssertEqual(sealed.ciphertext.count, plaintext.count + HPKETestFixtures.tagLength)
    }

    // MARK: - Ciphersuite and parameters

    internal func testSealedPayloadDoesNotOpenWithADifferentRecipientKey() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let otherKey = P256.KeyAgreement.PrivateKey()

        let sealed = try encryptor.seal(Data([0x01, 0x02]), recipientPublicKey: recipientKey.publicKey.x963Representation)

        XCTAssertThrowsError(try HPKETestFixtures.baselineOpen(
            sealed.ciphertext,
            encapsulatedKey: sealed.encapsulatedKey,
            privateKey: otherKey
        ))
    }

    internal func testSealUsesAnEmptyInfo() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let sealed = try encryptor.seal(Data([0x01, 0x02]), recipientPublicKey: recipientKey.publicKey.x963Representation)

        var recipient = try HPKE.Recipient(
            privateKey: recipientKey,
            ciphersuite: .privyWalletApi,
            info: RFC9180Vectors.info,
            encapsulatedKey: sealed.encapsulatedKey
        )

        XCTAssertThrowsError(try recipient.open(sealed.ciphertext))
    }

    internal func testSealUsesNoAdditionalAuthenticatedData() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let sealed = try encryptor.seal(Data([0x01, 0x02]), recipientPublicKey: recipientKey.publicKey.x963Representation)

        var recipient = try HPKE.Recipient(
            privateKey: recipientKey,
            ciphersuite: .privyWalletApi,
            info: Data(),
            encapsulatedKey: sealed.encapsulatedKey
        )

        XCTAssertThrowsError(try recipient.open(sealed.ciphertext, authenticating: Data("Count-0".utf8)))
    }

    internal func testSealUsesChaChaPolyRatherThanAESGCM() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let sealed = try encryptor.seal(Data([0x01, 0x02]), recipientPublicKey: recipientKey.publicKey.x963Representation)

        var aesRecipient = try HPKE.Recipient(
            privateKey: recipientKey,
            ciphersuite: HPKE.Ciphersuite(kem: .P256_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .AES_GCM_256),
            info: Data(),
            encapsulatedKey: sealed.encapsulatedKey
        )

        XCTAssertThrowsError(try aesRecipient.open(sealed.ciphertext))
    }

    // MARK: - Output format

    internal func testEncapsulatedKeyIsAnUncompressedPointOnTheCurve() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()

        let sealed = try encryptor.seal(Data([0x01]), recipientPublicKey: recipientKey.publicKey.x963Representation)

        XCTAssertEqual(sealed.encapsulatedKey.count, HPKETestFixtures.uncompressedPointLength)
        XCTAssertEqual(sealed.encapsulatedKey.first, 0x04)
        XCTAssertNoThrow(try P256.KeyAgreement.PublicKey(x963Representation: sealed.encapsulatedKey))
        XCTAssertNotEqual(sealed.encapsulatedKey, recipientKey.publicKey.x963Representation)
    }

    internal func testCiphertextLengthIsPlaintextPlusTag() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()

        for length in [0, 1, 15, 16, 17, 31, 32, 33, 64, 255, 256, 1024, 4096] {
            let sealed = try encryptor.seal(
                HPKETestFixtures.randomBytes(length),
                recipientPublicKey: recipientKey.publicKey.x963Representation
            )

            XCTAssertEqual(sealed.ciphertext.count, length + HPKETestFixtures.tagLength, "plaintext length \(length)")
            XCTAssertEqual(sealed.encapsulatedKey.count, HPKETestFixtures.uncompressedPointLength)
        }
    }

    internal func testEachSealUsesAFreshEphemeralKey() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let plaintext = Data(repeating: 0x2A, count: 32)

        var encapsulatedKeys = Set<Data>()
        var ciphertexts = Set<Data>()
        for _ in 0 ..< 10 {
            let sealed = try encryptor.seal(plaintext, recipientPublicKey: recipientKey.publicKey.x963Representation)
            encapsulatedKeys.insert(sealed.encapsulatedKey)
            ciphertexts.insert(sealed.ciphertext)
        }

        XCTAssertEqual(encapsulatedKeys.count, 10)
        XCTAssertEqual(ciphertexts.count, 10)
    }

    internal func testCiphertextDoesNotContainThePlaintext() throws {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let plaintext = Data(HPKETestFixtures.asciiString(byteCount: 64).utf8)

        let sealed = try encryptor.seal(plaintext, recipientPublicKey: recipientKey.publicKey.x963Representation)

        XCTAssertNil(sealed.ciphertext.range(of: plaintext.prefix(16)))
    }

    // MARK: - Recipient key validation

    internal func testRejectsAnSpkiEncodedKey() {
        let recipientKey = P256.KeyAgreement.PrivateKey()

        assertRejects(recipientKey.publicKey.derRepresentation)
    }

    internal func testRejectsABase64SpkiKey() {
        let recipientKey = P256.KeyAgreement.PrivateKey()

        assertRejects(Data(recipientKey.publicKey.derRepresentation.base64EncodedString().utf8))
    }

    internal func testRejectsACompressedKey() {
        let recipientKey = P256.KeyAgreement.PrivateKey()

        assertRejects(recipientKey.publicKey.compressedRepresentation)
    }

    internal func testRejectsARawCoordinatesKeyWithoutPrefix() {
        let recipientKey = P256.KeyAgreement.PrivateKey()

        assertRejects(recipientKey.publicKey.rawRepresentation)
    }

    internal func testRejectsAPointNotOnTheCurve() {
        assertRejects(Data([0x04] + [UInt8](repeating: 0x01, count: 64)))
    }

    internal func testRejectsAPointWithATamperedCoordinate() {
        let recipientKey = P256.KeyAgreement.PrivateKey()
        let tampered = HPKETestFixtures.flippingBit(
            in: recipientKey.publicKey.x963Representation,
            atOffset: HPKETestFixtures.uncompressedPointLength - 1
        )

        assertRejects(tampered)
    }

    internal func testRejectsWrongLengthKeys() {
        let point = Array(P256.KeyAgreement.PrivateKey().publicKey.x963Representation)

        assertRejects(Data())
        assertRejects(Data([0x04]))
        assertRejects(Data(point.dropLast()))
        assertRejects(Data(point + [0x00]))
        assertRejects(Data(point + point))
    }

    internal func testRejectsWrongPrefixKeys() {
        let coordinates = Array(P256.KeyAgreement.PrivateKey().publicKey.x963Representation.dropFirst())

        for prefix: UInt8 in [0x00, 0x02, 0x03, 0x05, 0x06, 0x07, 0xFF] {
            assertRejects(Data([prefix] + coordinates), "prefix \(prefix)")
        }
    }

    // MARK: - Helpers

    private func assertRejects(
        _ recipientPublicKey: Data,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try encryptor.seal(Data([0x01]), recipientPublicKey: recipientPublicKey),
            message,
            file: file,
            line: line
        ) { error in
            HPKETestFixtures.assertInvalidRecipientPublicKey(error, file: file, line: line)
        }
    }
}
