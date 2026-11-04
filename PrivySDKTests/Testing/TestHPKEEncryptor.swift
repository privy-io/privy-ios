import Foundation
@testable import PrivySDK

/// In-memory `HPKEEncryptor` test double that records its inputs and returns a fixed payload.
internal final class TestHPKEEncryptor: HPKEEncryptor, @unchecked Sendable {
    internal static let sealedPayload = HPKESealedPayload(
        encapsulatedKey: Data([0x04] + [UInt8](repeating: 0xEE, count: 64)),
        ciphertext: Data(repeating: 0xCC, count: 48)
    )

    internal private(set) var sealRequests: [(plaintext: Data, recipientPublicKey: Data)] = []

    internal func seal(_ plaintext: Data, recipientPublicKey: Data) throws -> HPKESealedPayload {
        sealRequests.append((plaintext, recipientPublicKey))
        return Self.sealedPayload
    }
}
