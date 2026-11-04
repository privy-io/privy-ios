import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var authSessionRepository: Factory<AuthSessionTokensRepository> {
        self { AuthSessionTokensRepositoryImpl() }.shared
    }
}

internal protocol AuthSessionTokensRepository: Sendable {
    func save(authTokens auth: AuthSessionTokens) async throws

    func retrieveAuthTokens() async -> AuthSessionTokens?

    func deleteAuthTokens() async
}

private final class AuthSessionTokensRepositoryImpl: AuthSessionTokensRepository {
    private enum Constants {
        // Note: Do not change these or it will break backwards compatibility
        static let authTokensPersistenceKeyV4 = "authTokensV4"

        // Note: Legacy v3 tokens were stored without kSecAttrAccessibleAfterFirstUnlock,
        // causing keychain reads to fail when iOS cold-starts the app in the background
        // with the device locked. V4 tokens are stored with the correct accessibility.
        static let authTokensPersistenceKeyV3 = "authTokensV3"

        // Note: Legacy v2 values had service and account flipped, so use KeychainManager directly
        static let authKeychainServiceV2 = "authTokensV2"
        static let authKeychainAccountV2 = "io.privy"
    }

    private let logger: Logger = resolve(\PrivyContainer.logger)
    private let storageAdapter: StorageAdapter = resolve(\PrivyContainer.storageAdapter)

    func save(authTokens: AuthSessionTokens) async throws {
        let data = try JSONEncoder().encode(authTokens)
        let _ = try await storageAdapter.createOrUpdate(key: Constants.authTokensPersistenceKeyV4, data: data)
    }

    func retrieveAuthTokens() async -> AuthSessionTokens? {
        // Run migrations sequentially: v2 -> v3 -> v4
        await migrateV2TokensIfNeeded()
        await migrateV3TokensIfNeeded()

        // By this point, any legacy tokens have been migrated to v4
        guard let tokenData = await storageAdapter.get(key: Constants.authTokensPersistenceKeyV4) else {
            return nil
        }

        do {
            let item = try JSONDecoder().decode(AuthSessionTokens.self, from: tokenData)
            logger.debugInternal("Successfully read \(Constants.authTokensPersistenceKeyV4) from storage")
            return item
        } catch {
            logger.debugInternal("Failed to decode \(Constants.authTokensPersistenceKeyV4) from storage")
            return nil
        }
    }

    private func migrateV2TokensIfNeeded() async {
        // Migrate v2 data to v3. V2 had service and account flipped, so we must use
        // KeychainManager directly rather than StorageAdapter.
        // It is safe to use AuthSessionTokens struct on the v2 format because it is
        // backwards compatible on the "important" properties (all minus the user).
        // The v3 -> v4 migration will run immediately after.
        guard let authSessionV2Data = KeychainManager.read(
            service: Constants.authKeychainServiceV2,
            account: Constants.authKeychainAccountV2,
            type: AuthSessionTokens.self
        ) else {
            return
        }

        logger.info("Migrating legacy v2 session data to v3")
        KeychainManager.delete(service: Constants.authKeychainServiceV2, account: Constants.authKeychainAccountV2)

        do {
            let data = try JSONEncoder().encode(authSessionV2Data)
            let _ = try await storageAdapter.createOrUpdate(key: Constants.authTokensPersistenceKeyV3, data: data)
            logger.verbose("Stored migrated v2 session data as v3")
        } catch {
            logger.error("Failed to save v2 -> v3 migration", error: error)
        }
    }

    private func migrateV3TokensIfNeeded() async {
        // V3 tokens were stored without kSecAttrAccessibleAfterFirstUnlock, causing
        // keychain reads to fail when iOS cold-starts the app in the background with
        // the device locked. Re-saving as v4 writes them with the correct accessibility.
        guard let tokenData = await storageAdapter.get(key: Constants.authTokensPersistenceKeyV3) else {
            return
        }

        guard let authSessionTokens = try? JSONDecoder().decode(AuthSessionTokens.self, from: tokenData) else {
            logger.debugInternal("Failed to decode \(Constants.authTokensPersistenceKeyV3) during migration")
            return
        }

        logger.info("Migrating v3 session data to v4 (adding kSecAttrAccessibleAfterFirstUnlock)")
        await storageAdapter.delete(key: Constants.authTokensPersistenceKeyV3)

        do {
            try await save(authTokens: authSessionTokens)
            logger.verbose("Stored migrated v3 session data as v4")
        } catch {
            logger.error("Failed to save v3 -> v4 migration", error: error)
        }
    }

    func deleteAuthTokens() async {
        // v4 - current auth session tokens
        await storageAdapter.delete(key: Constants.authTokensPersistenceKeyV4)
        // v3 - clean up legacy tokens if they exist (e.g. migration hadn't run yet)
        await storageAdapter.delete(key: Constants.authTokensPersistenceKeyV3)
    }
}
