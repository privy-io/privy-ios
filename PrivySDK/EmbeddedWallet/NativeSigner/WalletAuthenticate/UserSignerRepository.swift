import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var userSignerRepository: Factory<UserSignerRepository> {
        self { UserSignerRepositoryImpl() }.shared
    }
}

internal protocol UserSignerRepository: Sendable {
    func getUserSigner(authToken: String, mfaToken: String?) async throws -> UserSignerKey
    func clearUserSigner() async
}

private final class UserSignerRepositoryImpl: UserSignerRepository {
    private static let expiryBufferMs = 30 * 1000

    private let networkService: NetworkService = resolve(\PrivyContainer.networkService)
    private let hpkeDecryptor: HPKEDecryptor = resolve(\PrivyContainer.hpkeDecryptor)
    private let userSignerStorage: UserSignerStorage = resolve(\PrivyContainer.userSignerStorage)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    internal func getUserSigner(authToken: String, mfaToken: String?) async throws -> UserSignerKey {
        if let cached = await getValidCachedUserSigner() {
            return cached
        }

        return try await fetchAndCacheUserSigner(authToken: authToken, mfaToken: mfaToken)
    }

    private func getValidCachedUserSigner() async -> UserSignerKey? {
        guard let cached = await userSignerStorage.retrieve() else {
            logger.verbose("No cached user signer found, fetching new one")
            return nil
        }

        // expiresAt is in milliseconds (from backend's Date.getTime())
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        let remainingMs = cached.expiresAtMs - nowMs
        let remainingSeconds = remainingMs / 1000

        logger.verbose("Cache check: expiresAtMs=\(cached.expiresAtMs), nowMs=\(nowMs), remainingMs=\(remainingMs)")

        guard remainingMs > Self.expiryBufferMs else {
            logger.verbose("Cached user signer expired or within buffer (remaining: \(remainingSeconds)s), clearing and fetching new one")
            await userSignerStorage.delete()
            return nil
        }

        logger.verbose("Using cached user signer (expires in \(remainingSeconds)s)")
        return cached
    }

    internal func clearUserSigner() async {
        logger.verbose("Clearing cached user signer")
        await userSignerStorage.delete()
    }

    private func fetchAndCacheUserSigner(authToken: String, mfaToken: String?) async throws -> UserSignerKey {
        let keypair = try hpkeDecryptor.generateEphemeralKeypair()

        let body = WalletAuthenticateRequest(
            userJwt: authToken,
            encryptionType: "HPKE",
            recipientPublicKey: keypair.publicKeyBase64SPKI
        )

        logger.verbose("Calling /wallets/authenticate to fetch user signer")

        let response: WalletAuthenticateResponse
        do {
            var request = try await networkService.makeRequest(
                path: "/api/v1/wallets/authenticate",
                token: authToken
            )

            if let mfaToken {
                request.setValue(mfaToken, forHTTPHeaderField: "privy-mfa-token")
            }

            request.httpBody = try JSONEncoder().encode(body)

            response = try await request.execute()
        } catch {
            logger.error("Failed to fetch user signer from /wallets/authenticate", error: error)
            throw error
        }

        let privateKeyBase64 = try hpkeDecryptor.decrypt(
            ciphertext: response.encryptedAuthorizationKey.ciphertext,
            encapsulatedKey: response.encryptedAuthorizationKey.encapsulatedKey,
            privateKey: keypair.privateKey
        )

        let userSigner = UserSignerKey(
            privateKeyBase64: privateKeyBase64,
            expiresAtMs: response.expiresAt
        )

        try await userSignerStorage.save(userSigner: userSigner)

        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        let expiresInSeconds = (response.expiresAt - nowMs) / 1000
        logger.verbose("User signer fetched and cached (response.expiresAt=\(response.expiresAt), nowMs=\(nowMs), expires in \(expiresInSeconds)s)")

        return userSigner
    }
}
