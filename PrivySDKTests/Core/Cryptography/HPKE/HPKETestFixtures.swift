import CryptoKit
import XCTest
@testable import PrivySDK

/// Known-answer values for DHKEM(P-256, HKDF-SHA256), HKDF-SHA256, ChaCha20Poly1305 in base mode
/// (KEM 0x0010, KDF 0x0001, AEAD 0x0003): the suite behind ``HPKE/Ciphersuite/privyWalletApi``.
///
/// Source: RFC 9180, appendix A.5.1 (https://www.rfc-editor.org/rfc/rfc9180.txt), cross-checked
/// against the mode 0 entry for this suite in the CFRG `test-vectors.json`
/// (https://github.com/cfrg/draft-irtf-cfrg-hpke). `info`, `aad`, `pt` and the exporter contexts
/// are ASCII, so they are written as strings rather than hex.
internal enum RFC9180Vectors {
    /// A.5.1 `info` (hex `4f64…726e`).
    internal static let info = Data("Ode on a Grecian Urn".utf8)

    /// A.5.1 `skRm`, the recipient's raw private scalar.
    internal static let recipientPrivateKey = HPKETestFixtures.bytes(
        "a4d1c55836aa30f9b3fbb6ac98d338c877c2867dd3a77396d13f68d3ab150d3b"
    )

    /// A.5.1 `pkRm`, the recipient's uncompressed public key.
    internal static let recipientPublicKey = HPKETestFixtures.bytes(
        "04a697bffde9405c992883c5c439d6cc358170b51af72812333b015621dc0f40"
            + "bad9bb726f68a5c013806a790ec716ab8669f84f6b694596c2987cf35baba2a006"
    )

    /// A.5.1 `enc`, the sender's encapsulated ephemeral key (equal to `pkEm`).
    internal static let encapsulatedKey = HPKETestFixtures.bytes(
        "04c07836a0206e04e31d8ae99bfd549380b072a1b1b82e563c935c095827824f"
            + "c1559eac6fb9e3c70cd3193968994e7fe9781aa103f5b50e934b5b2f387e381291"
    )

    /// The `pt` shared by every A.5.1.1 encryption.
    internal static let plaintext = "Beauty is truth, truth beauty"

    /// A single A.5.1.1 encryption.
    internal struct Encryption {
        /// The sequence number of the encryption within the context.
        internal let sequenceNumber: Int

        /// The additional authenticated data, `Count-<sequenceNumber>`.
        internal let aad: Data

        /// The ciphertext, including the authentication tag.
        internal let ciphertext: Data
    }

    /// The first three A.5.1.1 encryptions. Later ones (sequence numbers 4, 255 and 256) can't be
    /// reached with a CryptoKit recipient without the intermediate ciphertexts.
    internal static let encryptions: [Encryption] = [
        Encryption(
            sequenceNumber: 0,
            aad: Data("Count-0".utf8),
            ciphertext: HPKETestFixtures.bytes(
                "6469c41c5c81d3aa85432531ecf6460ec945bde1eb428cb2fedf7a29f5a685b4"
                    + "ccb0d057f03ea2952a27bb458b"
            )
        ),
        Encryption(
            sequenceNumber: 1,
            aad: Data("Count-1".utf8),
            ciphertext: HPKETestFixtures.bytes(
                "f1564199f7e0e110ec9c1bcdde332177fc35c1adf6e57f8d1df24022227ffa87"
                    + "16862dbda2b1dc546c9d114374"
            )
        ),
        Encryption(
            sequenceNumber: 2,
            aad: Data("Count-2".utf8),
            ciphertext: HPKETestFixtures.bytes(
                "39de89728bcb774269f882af8dc5369e4f3d6322d986e872b3a8d074c7c18e85"
                    + "49ff3f85b6d6592ff87c3f310c"
            )
        ),
    ]

    /// A single A.5.1.2 exported value.
    internal struct Export {
        /// The exporter context.
        internal let context: Data

        /// The expected 32-byte exported secret.
        internal let value: Data
    }

    /// The A.5.1.2 exported values, all with `L` = 32.
    internal static let exports: [Export] = [
        Export(
            context: Data(),
            value: HPKETestFixtures.bytes("9b13c510416ac977b553bf1741018809c246a695f45eff6d3b0356dbefe1e660")
        ),
        Export(
            context: Data([0x00]),
            value: HPKETestFixtures.bytes("6c8b7be3a20a5684edecb4253619d9051ce8583baf850e0cb53c402bdcaf8ebb")
        ),
        Export(
            context: Data("TestContext".utf8),
            value: HPKETestFixtures.bytes("477a50d804c7c51941f69b8e32fe8288386ee1a84905fe4938d58972f24ac938")
        ),
    ]
}

/// Shared helpers for the HPKE test suites.
internal enum HPKETestFixtures {
    /// Ciphertext overhead of ChaCha20-Poly1305: the 16-byte authentication tag.
    internal static let tagLength = 16

    /// Length of an uncompressed P-256 point, `0x04 || X || Y`.
    internal static let uncompressedPointLength = 65

    /// Decodes a lowercase or uppercase hex string. Traps on malformed input; test-only.
    internal static func bytes(_ hex: String) -> Data {
        precondition(hex.count.isMultiple(of: 2), "Odd-length hex string")
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else {
                preconditionFailure("Invalid hex byte: \(hex[index ..< next])")
            }
            data.append(byte)
            index = next
        }
        return data
    }

    /// `count` cryptographically random bytes.
    internal static func randomBytes(_ count: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0 ..< count).map { _ in generator.next() })
    }

    /// An ASCII string of exactly `count` UTF-8 bytes, cycling through printable characters so
    /// distinct offsets hold distinct bytes.
    internal static func asciiString(byteCount count: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/")
        return String((0 ..< count).map { alphabet[$0 % alphabet.count] })
    }

    /// `data` with one bit flipped at `offset` from its start. Works on `Data` slices, whose indices
    /// don't start at zero (CryptoKit returns ciphertexts as slices).
    internal static func flippingBit(in data: Data, atOffset offset: Int) -> Data {
        var bytes = Array(data)
        bytes[offset] ^= 0x01
        return Data(bytes)
    }

    /// Opens `ciphertext` the way the Privy Wallet API does: an independent CryptoKit recipient
    /// with ``HPKE/Ciphersuite/privyWalletApi``, an empty `info` and no additional authenticated data.
    internal static func baselineOpen(
        _ ciphertext: Data,
        encapsulatedKey: Data,
        privateKey: P256.KeyAgreement.PrivateKey
    ) throws -> Data {
        var recipient = try HPKE.Recipient(
            privateKey: privateKey,
            ciphersuite: .privyWalletApi,
            info: Data(),
            encapsulatedKey: encapsulatedKey
        )
        return try recipient.open(ciphertext)
    }

    /// Seals `plaintext` the way the Privy Wallet API does: an independent CryptoKit sender with
    /// ``HPKE/Ciphersuite/privyWalletApi``, an empty `info` and no additional authenticated data.
    ///
    /// - Returns: The ciphertext and encapsulated key, both base64-encoded as the API returns them.
    internal static func baselineSeal(
        _ plaintext: Data,
        to publicKey: P256.KeyAgreement.PublicKey
    ) throws -> (ciphertext: String, encapsulatedKey: String) {
        var sender = try HPKE.Sender(recipientKey: publicKey, ciphersuite: .privyWalletApi, info: Data())
        let ciphertext = try sender.seal(plaintext)
        return (ciphertext.base64EncodedString(), sender.encapsulatedKey.base64EncodedString())
    }

    /// Asserts that `error` is ``HPKEError/invalidRecipientPublicKey``.
    internal static func assertInvalidRecipientPublicKey(
        _ error: Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .invalidRecipientPublicKey? = error as? HPKEError else {
            return XCTFail("Expected HPKEError.invalidRecipientPublicKey, got \(error)", file: file, line: line)
        }
    }

    /// Asserts that `error` is ``HPKEError/invalidBase64(_:)`` for `field`.
    internal static func assertInvalidBase64(
        _ error: Error,
        field: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .invalidBase64(let actualField)? = error as? HPKEError else {
            return XCTFail("Expected HPKEError.invalidBase64, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(actualField, field, file: file, line: line)
    }

    /// Asserts that `error` came from CryptoKit (`CryptoKitError` or `HPKE.Errors`) rather than
    /// from one of the SDK's own ``HPKEError`` checks.
    internal static func assertCryptoKitError(
        _ error: Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            error is CryptoKitError || error is HPKE.Errors,
            "Expected a CryptoKit error, got \(error)",
            file: file,
            line: line
        )
    }
}
