import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Creating a first wallet fails if the chain has any embedded wallet, imported ones included.
/// With `allowAdditional`, it always works.
internal final class EmbeddedWalletCreatorTests: PrivyTestCase {
    private static let hdWallet = EmbeddedEthereumWalletAccount.test(id: "hd-wallet-id", address: "0x1111111111111111111111111111111111111111")
    private static let importedWallet = EmbeddedEthereumWalletAccount.test(
        id: "imported-wallet-id",
        address: "0x2222222222222222222222222222222222222222",
        imported: true
    )
    private static let newWalletAddress = "0x3333333333333333333333333333333333333333"

    private var testAuthManager: TestAuthManager!
    private var testWalletApiRepository: TestWalletApiRepository!
    private var testWebviewHandler: TestWebviewHandler!

    override internal func setUp() {
        super.setUp()

        let testAuthManager = TestAuthManager()
        let testWalletApiRepository = TestWalletApiRepository()
        testWalletApiRepository.createWalletResult = .success(
            WalletApiCreateResponse(id: "new-wallet-id", address: Self.newWalletAddress, chainType: .ethereum)
        )
        let testWebviewHandler = TestWebviewHandler()

        register(\PrivyContainer.authManager) { testAuthManager }
        register(\PrivyContainer.walletApiRepository) { testWalletApiRepository }
        register(\PrivyContainer.webViewHandler) { testWebviewHandler }

        self.testAuthManager = testAuthManager
        self.testWalletApiRepository = testWalletApiRepository
        self.testWebviewHandler = testWebviewHandler
    }

    // MARK: - Wallet API

    internal func testWalletApiBlocksAFirstWalletNextToAnImportedWallet() async {
        authenticate(with: [.embeddedEthereumWallet(Self.importedWallet)])

        await XCTAssertThrowsErrorAsync(
            try await Self.creator(.userControlledServerWalletsOnly).createWallet(chainType: .ethereum, allowAdditional: false, timeout: .seconds(1))
        ) { error in
            Self.assertAdditionalWalletsBlocked(error)
        }

        XCTAssertTrue(testWalletApiRepository.createWalletRequests.isEmpty)
    }

    internal func testWalletApiCreatesAWalletNextToAnImportedWalletWithAllowAdditional() async throws {
        authenticate(with: [.embeddedEthereumWallet(Self.importedWallet)])

        let wallet = try await Self.creator(.userControlledServerWalletsOnly).createWallet(chainType: .ethereum, allowAdditional: true, timeout: .seconds(1))

        XCTAssertEqual(wallet.address, Self.newWalletAddress)
        XCTAssertEqual(testWalletApiRepository.createWalletRequests.count, 1)
    }

    // MARK: - Webview

    internal func testWebViewBlocksAFirstWalletNextToAnImportedWallet() async {
        authenticate(with: [.embeddedEthereumWallet(Self.importedWallet)])

        await XCTAssertThrowsErrorAsync(
            try await Self.creator(.legacyEmbeddedWalletsOnly).createWallet(chainType: .ethereum, allowAdditional: false, timeout: .seconds(1))
        ) { error in
            Self.assertAdditionalWalletsBlocked(error)
        }

        XCTAssertTrue(testWebviewHandler.createEthereumWalletRequests.isEmpty)
    }

    internal func testWebViewCreatesAPrimaryWalletNextToAnImportedWalletWithAllowAdditional() async throws {
        authenticate(with: [.embeddedEthereumWallet(Self.importedWallet)])
        testWebviewHandler.createEthereumWalletResult = .success(
            CreateEthereumWalletResponse(id: "request-id", data: CreateEthereumWalletResponseData(address: Self.newWalletAddress))
        )

        let wallet = try await Self.creator(.legacyEmbeddedWalletsOnly).createWallet(chainType: .ethereum, allowAdditional: true, timeout: .seconds(1))

        XCTAssertEqual(wallet.address, Self.newWalletAddress)
        XCTAssertEqual(testWebviewHandler.createEthereumWalletRequests.count, 1)
    }

    internal func testWebViewCreatesAnAdditionalWalletFromTheHdPrimaryNextToAnImportedWallet() async throws {
        authenticate(with: [.embeddedEthereumWallet(Self.importedWallet), .embeddedEthereumWallet(Self.hdWallet)])
        testWebviewHandler.createAdditionalWalletResult = .success(
            ChainAgnosticCreateAdditionalWalletResponse(
                id: "request-id",
                data: ChainAgnosticCreateAdditionalWalletResponseData(address: Self.newWalletAddress)
            )
        )

        let wallet = try await Self.creator(.legacyEmbeddedWalletsOnly).createWallet(chainType: .ethereum, allowAdditional: true, timeout: .seconds(1))

        XCTAssertEqual(wallet.address, Self.newWalletAddress)
        XCTAssertEqual(testWebviewHandler.createAdditionalWalletRequests.first?.entropyId, Self.hdWallet.address)
    }

    // MARK: - Helpers

    private func authenticate(with linkedAccounts: [LinkedAccount]) {
        let session = InternalAuthSession.test(linkedAccounts: linkedAccounts)
        testAuthManager.ensureAuthenticatedResult = .success(session)
        testAuthManager.refreshSessionIfNeededResult = .success(session)
    }

    private static func creator(_ mode: EmbeddedWalletMode) -> EmbeddedWalletCreator {
        PrivyContainer.shared.embeddedWalletCreator(AppConfig(embeddedWalletConfig: EmbeddedWalletConfig(mode: mode)))
    }

    private static func assertAdditionalWalletsBlocked(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        guard case .embeddedWalletFailure(.additionalWalletsBlocked) = (error as? PrivyError)?.errorCode else {
            return XCTFail("Expected .additionalWalletsBlocked, got \(error)", file: file, line: line)
        }
    }
}
