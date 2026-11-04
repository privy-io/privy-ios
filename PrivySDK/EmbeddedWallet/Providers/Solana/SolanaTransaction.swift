import Foundation
internal import FactoryKit

internal struct SolanaTransaction {
    /// The message bytes of the Solana transaction
    internal let message: Data

    /// Parses the encoded bytes of a Solana transaction
    /// - Parameters:
    ///   - transaction: The serialized transaction bytes
    /// - Returns: The Solana transaction
    internal init(bytes: Data) throws {
        guard bytes.count >= 4 else {
            throw PrivyError(.embeddedWalletFailure(reason: .invalidSolanaTransaction(details: "Transactions have a minimum length of 4 bytes")))
        }

        guard let (signatureCount, nextPosition) = try? bytes.readCompactU16(position: 0) else {
            throw PrivyError(.embeddedWalletFailure(reason: .invalidSolanaTransaction(details: "Unable to read the signature count")))
        }

        let signatureHeaderLength = nextPosition - 1
        let signaturePayloadLength = 64 * Int(signatureCount)
        let signatureBlockLength = signatureHeaderLength + signaturePayloadLength

        let messagePosition = signatureBlockLength + 1
        guard messagePosition < bytes.count else {
            throw PrivyError(.embeddedWalletFailure(reason: .invalidSolanaTransaction(details: "No message bytes found after signatures")))
        }

        self.message = bytes.suffix(from: messagePosition)
    }

    /// Encodes the parsed transaction as a signed transaction adding the given signature
    ///
    /// - Parameters:
    ///   - signature: The 64-byte Ed25519 signature
    /// - Returns: The encoded signed transaction
    internal func add(signature: Data) throws -> Data {
        guard signature.count == 64 else {
            throw PrivyError(.embeddedWalletFailure(reason: .invalidSolanaTransaction(details: "The computed signature for the transaction must be 64 bytes long")))
        }

        // Build transaction with single signature
        // Format: [0x01][64-byte signature][message bytes]
        var transaction = Data([0x01])
        transaction.append(signature)
        transaction.append(self.message)

        return transaction
    }
}

fileprivate extension Data {
    /// Reads a Compact U16 value (variable-length encoding)
    /// - Parameters:
    ///   - position: The position of the byte array from which to start reading the U16
    /// - Returns: A tuple of the UInt16 value parsed along the new index from which to read the following value
    func readCompactU16(position: Data.Index) throws -> (UInt16, Data.Index)? {
        var result: UInt16 = 0

        for offset in 0 ... 2 {
            let ix = position + offset
            let shift = 7 * offset

            guard ix < count else {
                return nil
            }

            let byte = self[ix]

            // Extract lower 7 bits and add to result at the current shift position
            result |= UInt16(byte & 0x7f) << shift

            // If high bit is not set, we're done
            if byte & 0x80 == 0 {
                return (result, ix + 1)
            }
        }

        // All 3 bytes were used and the last byte had the high bit set,
        // which is invalid.
        return nil
    }
}
