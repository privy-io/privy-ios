import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var userSignerStorage: Factory<UserSignerStorage> {
        self { UserSignerStorageImpl() }.shared
    }
}

internal protocol UserSignerStorage: Sendable {
    func save(userSigner: UserSignerKey) async throws
    func retrieve() async -> UserSignerKey?
    func delete() async
}

private final class UserSignerStorageImpl: UserSignerStorage {
    private enum Constants {
        static let signerKeyV1 = "userSignerV1"
    }

    private let storageAdapter: StorageAdapter = resolve(\PrivyContainer.storageAdapter)

    internal func save(userSigner: UserSignerKey) async throws {
        let data = try JSONEncoder().encode(userSigner)
        try await storageAdapter.createOrUpdate(key: Constants.signerKeyV1, data: data)
    }

    internal func retrieve() async -> UserSignerKey? {
        guard let data = await storageAdapter.get(key: Constants.signerKeyV1) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(UserSignerKey.self, from: data)
        } catch {
            return nil
        }
    }

    internal func delete() async {
        await storageAdapter.delete(key: Constants.signerKeyV1)
    }
}
