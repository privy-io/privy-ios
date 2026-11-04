import CryptoKit

internal extension HPKE.Ciphersuite {
    /// The suite the Privy Wallet API uses for HPKE in both directions: DHKEM(P-256, HKDF-SHA256),
    /// HKDF-SHA256 and ChaCha20-Poly1305, in base mode with an empty `info`.
    static var privyWalletApi: HPKE.Ciphersuite {
        HPKE.Ciphersuite(kem: .P256_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .chaChaPoly)
    }
}
