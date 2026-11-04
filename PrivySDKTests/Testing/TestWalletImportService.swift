import Foundation
@testable import PrivySDK

/// In-memory `WalletImportService` test double that records its inputs and returns a fixed result.
internal final class TestWalletImportService: WalletImportService, @unchecked Sendable {
    /// `nil` fatal-errors, so a test that imports must say what the import returns.
    internal var importWalletResult: Result<any EmbeddedWalletAccount, Error>?
    internal private(set) var importWalletRequests: [(chainType: WalletImportSupportedChainType, address: String)] = []

    internal func importWallet(
        _ secret: WalletImportSecret,
        chainType: WalletImportSupportedChainType,
        address: String
    ) async throws -> any EmbeddedWalletAccount {
        guard let importWalletResult else {
            fatalError("TestWalletImportService.importWallet was called but isn't stubbed for this test.")
        }
        importWalletRequests.append((chainType, address))
        return try importWalletResult.get()
    }
}
