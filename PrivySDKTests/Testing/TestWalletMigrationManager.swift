import Foundation
@testable import PrivySDK

/// In-memory `WalletMigrationManager` test double.
internal final class TestWalletMigrationManager: WalletMigrationManager, @unchecked Sendable {
    internal var migrateWalletsIfNeededResult: Result<Void, Error> = .success(())
    internal private(set) var migrateWalletsIfNeededCallCount = 0

    internal func migrateWalletsIfNeeded() async throws {
        migrateWalletsIfNeededCallCount += 1
        try migrateWalletsIfNeededResult.get()
    }
}
