import XCTest
@testable import PrivySDK

/// Imported wallets usually report index 0, the same as the user's Privy HD primary, so the
/// primary wallet helpers must skip them whatever the list order.
internal final class LinkedAccountTests: XCTestCase {
    private static let hdEthereumWallet = EmbeddedEthereumWalletAccount.test(id: "hd-wallet-id", address: "0x1111111111111111111111111111111111111111")
    private static let importedEthereumWallet = EmbeddedEthereumWalletAccount.test(
        id: "imported-wallet-id",
        address: "0x2222222222222222222222222222222222222222",
        imported: true
    )
    private static let hdSolanaWallet = EmbeddedSolanaWalletAccount.test(id: "hd-wallet-id", address: "SoLanaWa11etA111111111111111111111111111111")
    private static let importedSolanaWallet = EmbeddedSolanaWalletAccount.test(
        id: "imported-wallet-id",
        address: "SoLanaWa11etB111111111111111111111111111111",
        imported: true
    )

    internal func testPrimaryEthereumWalletSkipsAnImportedWalletAtIndexZero() {
        let linkedAccounts: [LinkedAccount] = [.embeddedEthereumWallet(Self.hdEthereumWallet), .embeddedEthereumWallet(Self.importedEthereumWallet)]

        XCTAssertEqual(linkedAccounts.getPrimaryEmbeddedEthereumWalletAccount()?.id, "hd-wallet-id")
        XCTAssertEqual(Array(linkedAccounts.reversed()).getPrimaryEmbeddedEthereumWalletAccount()?.id, "hd-wallet-id")
    }

    internal func testPrimarySolanaWalletSkipsAnImportedWalletAtIndexZero() {
        let linkedAccounts: [LinkedAccount] = [.embeddedSolanaWallet(Self.hdSolanaWallet), .embeddedSolanaWallet(Self.importedSolanaWallet)]

        XCTAssertEqual(linkedAccounts.getPrimaryEmbeddedSolanaWalletAccount()?.id, "hd-wallet-id")
        XCTAssertEqual(Array(linkedAccounts.reversed()).getPrimaryEmbeddedSolanaWalletAccount()?.id, "hd-wallet-id")
    }

    internal func testImportedOnlyUserHasNoPrimaryWallet() {
        let linkedAccounts: [LinkedAccount] = [.embeddedEthereumWallet(Self.importedEthereumWallet), .embeddedSolanaWallet(Self.importedSolanaWallet)]

        XCTAssertNil(linkedAccounts.getPrimaryEmbeddedEthereumWalletAccount())
        XCTAssertNil(linkedAccounts.getPrimaryEmbeddedSolanaWalletAccount())
        XCTAssertThrowsError(try linkedAccounts.getPrimaryWalletForEntropyInfo())
    }
}
