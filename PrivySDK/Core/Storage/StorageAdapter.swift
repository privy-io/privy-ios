import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var storageAdapter: Factory<StorageAdapter> {
        self { PrivyKeychainStorageAdapter() }.unique
    }
}

public protocol StorageAdapter: Sendable {
    /// Saves or updates the data with the specified key
    /// - Parameters:
    ///   - key: The key to identify the saved data
    ///   - data: The data to be saved
    /// - Throws: If there was an error saving the data
    func createOrUpdate(key: String, data: Data) async throws

    /// Retrieves the data with the specified key or null if it doesn't exist
    /// - Parameters:
    ///   - key: The key to identify the saved data
    ///
    /// - Returns: The data stored with the specified key, or null if it doesn't exist.
    func get(key: String) async -> Data?

    /// Deletes the data with the specified key or does nothing if the value isn't stored
    /// - Parameters:
    ///   - key: The key to identify the saved data
    func delete(key: String) async
}

/// Privy's default storage adapter is backed by the Keychain
internal final class PrivyKeychainStorageAdapter: StorageAdapter {
    // All keychain values are stored using this service name.
    // Note: Do not change this or it will break backwards compatibility
    private static let authKeychainService = "io.privy"

    internal func createOrUpdate(key: String, data: Data) async throws {
        KeychainManager.createOrUpdate(
            data,
            service: PrivyKeychainStorageAdapter.authKeychainService,
            account: key
        )
    }

    internal func get(key: String) async -> Data? {
        KeychainManager.read(
            service: PrivyKeychainStorageAdapter.authKeychainService,
            account: key
        )
    }

    internal func delete(key: String) async {
        KeychainManager.delete(
            service: PrivyKeychainStorageAdapter.authKeychainService,
            account: key
        )
    }
}
