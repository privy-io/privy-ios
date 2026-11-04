import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class WalletImportServiceTests: PrivyTestCase {
    /// Address-shaped values; the server is faked, so they don't need to belong to the keys below.
    private static let ethereumAddress = "0x" + String(repeating: "aB", count: 20)
    private static let solanaAddress = "So11111111111111111111111111111111111111112"
    private static let ethereumPrivateKey = Data(repeating: 0x11, count: 32)
    private static let solanaSecretKey = Data(repeating: 0x22, count: 64)
    private static let mnemonic = Array(repeating: "abandon", count: 11).joined(separator: " ") + " about"
    private static let walletId = "imported-wallet-id"
    private static let initPublicKey = Data([0x04] + [UInt8](repeating: 0xAB, count: 64))

    private var testAuthManager: TestAuthManager!
    private var testAppConfigRepository: TestAppConfigRepository!
    private var testHPKEEncryptor: TestHPKEEncryptor!
    private var testWalletApiRepository: TestWalletApiRepository!
    private var testBreadcrumbEmitter: TestBreadcrumbEmitter!

    override internal func setUp() {
        super.setUp()

        let testAuthManager = TestAuthManager()
        testAuthManager.stubSession(refreshedLinkedAccounts: [Self.importedEthereumWallet()])
        let testAppConfigRepository = TestAppConfigRepository()
        let testHPKEEncryptor = TestHPKEEncryptor()
        let testWalletApiRepository = TestWalletApiRepository()
        testWalletApiRepository.initImportResult = .success(
            WalletApiImportInitResponse(encryptionPublicKey: Base64Data(Self.initPublicKey))
        )
        testWalletApiRepository.submitImportResult = .success(
            WalletApiCreateResponse(id: Self.walletId, address: Self.ethereumAddress, chainType: .ethereum)
        )
        let testBreadcrumbEmitter = TestBreadcrumbEmitter()

        register(\PrivyContainer.authManager) { testAuthManager }
        register(\PrivyContainer.appConfigRepository) { testAppConfigRepository }
        register(\PrivyContainer.hpkeEncryptor) { testHPKEEncryptor }
        register(\PrivyContainer.walletApiRepository) { testWalletApiRepository }
        register(\PrivyContainer.breadcrumbEmitter) { testBreadcrumbEmitter }

        self.testAuthManager = testAuthManager
        self.testAppConfigRepository = testAppConfigRepository
        self.testHPKEEncryptor = testHPKEEncryptor
        self.testWalletApiRepository = testWalletApiRepository
        self.testBreadcrumbEmitter = testBreadcrumbEmitter
    }

    // MARK: - Success

    internal func testImportInitsSealsAndSubmitsTheWallet() async throws {
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        let wallet = try await service.importWallet(.privateKey(Self.ethereumPrivateKey), chainType: .ethereum, address: Self.ethereumAddress)

        // Returns the wallet from the refreshed session
        XCTAssertEqual(wallet.id, Self.walletId)

        let initRequest = try XCTUnwrap(testWalletApiRepository.initImportRequests.first)
        XCTAssertEqual(testWalletApiRepository.initImportRequests.count, 1)
        XCTAssertEqual(initRequest.token, "test-auth-token")
        XCTAssertEqual(initRequest.params.address, Self.ethereumAddress)
        XCTAssertEqual(initRequest.params.chainType, .ethereum)
        XCTAssertEqual(initRequest.params.entropyType, .privateKey)
        XCTAssertNil(initRequest.params.index)

        // Seals the raw key bytes to the key returned by init
        let sealRequest = try XCTUnwrap(testHPKEEncryptor.sealRequests.first)
        XCTAssertEqual(testHPKEEncryptor.sealRequests.count, 1)
        XCTAssertEqual(sealRequest.recipientPublicKey, Self.initPublicKey)
        XCTAssertEqual(sealRequest.plaintext, Self.ethereumPrivateKey)

        // Submits the sealed output with the address
        let submitRequest = try XCTUnwrap(testWalletApiRepository.submitImportRequests.first)
        XCTAssertEqual(testWalletApiRepository.submitImportRequests.count, 1)
        XCTAssertEqual(submitRequest.token, "test-auth-token")
        XCTAssertEqual(submitRequest.params.wallet.address, Self.ethereumAddress)
        XCTAssertEqual(submitRequest.params.wallet.chainType, .ethereum)
        XCTAssertEqual(submitRequest.params.wallet.entropyType, .privateKey)
        XCTAssertNil(submitRequest.params.wallet.index)
        XCTAssertEqual(submitRequest.params.wallet.encapsulatedKey, Base64Data(TestHPKEEncryptor.sealedPayload.encapsulatedKey))
        XCTAssertEqual(submitRequest.params.wallet.ciphertext, Base64Data(TestHPKEEncryptor.sealedPayload.ciphertext))

        XCTAssertEqual(testBreadcrumbEmitter.emitted.map(\.event), ["wallet.import.started", "wallet.import.completed"])
        XCTAssertEqual(testBreadcrumbEmitter.emitted.map(\.data), [["chain-type": "ethereum"], ["chain-type": "ethereum"]])
    }

    internal func testImportsASolanaWallet() async throws {
        testAuthManager.stubSession(refreshedLinkedAccounts: [Self.importedSolanaWallet()])
        testWalletApiRepository.submitImportResult = .success(
            WalletApiCreateResponse(id: Self.walletId, address: Self.solanaAddress, chainType: .solana)
        )
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        let wallet = try await service.importWallet(.privateKey(Self.solanaSecretKey), chainType: .solana, address: Self.solanaAddress)

        XCTAssertEqual(wallet.chainType, .solana)
        XCTAssertEqual(wallet.address, Self.solanaAddress)
        XCTAssertEqual(testWalletApiRepository.initImportRequests.first?.params.chainType, .solana)
        XCTAssertEqual(testWalletApiRepository.submitImportRequests.first?.params.wallet.chainType, .solana)
        XCTAssertEqual(testHPKEEncryptor.sealRequests.first?.plaintext, Self.solanaSecretKey)
    }

    internal func testSeedPhraseImportSendsHdEntropyAtTheIndex() async throws {
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        _ = try await service.importWallet(.mnemonic(Self.mnemonic, index: 2), chainType: .ethereum, address: Self.ethereumAddress)

        let initRequest = try XCTUnwrap(testWalletApiRepository.initImportRequests.first)
        XCTAssertEqual(initRequest.params.entropyType, .hd)
        XCTAssertEqual(initRequest.params.index, 2)

        let submitRequest = try XCTUnwrap(testWalletApiRepository.submitImportRequests.first)
        XCTAssertEqual(submitRequest.params.wallet.entropyType, .hd)
        XCTAssertEqual(submitRequest.params.wallet.index, 2)

        // Seals the phrase as given
        XCTAssertEqual(testHPKEEncryptor.sealRequests.first?.plaintext, Data(Self.mnemonic.utf8))
    }

    // MARK: - Failures

    internal func testLegacyModeFailsBeforeAnyImportRequest() async {
        testAppConfigRepository.loadAppConfigResult = .success(
            AppConfig(embeddedWalletConfig: EmbeddedWalletConfig(mode: .legacyEmbeddedWalletsOnly))
        )
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        await XCTAssertThrowsErrorAsync(
            try await service.importWallet(.privateKey(Self.ethereumPrivateKey), chainType: .ethereum, address: Self.ethereumAddress)
        ) { error in
            Self.assertReason(error, is: "importNotSupported")
        }

        XCTAssertTrue(testWalletApiRepository.initImportRequests.isEmpty)
        XCTAssertEqual(testBreadcrumbEmitter.emitted.last?.event, "wallet.import.failed")
        XCTAssertEqual(testBreadcrumbEmitter.emitted.last?.data["error"], "embeddedWalletFailure.importNotSupported")
    }

    internal func testServerErrorsAreMappedFromTheirMessage() async {
        let cases: [(message: String, reason: String)] = [
            ("Wallet already exists", "walletAlreadyExists"),
            ("[Input error] Invalid address for specified chain type.", "invalidAddress"),
            ("Address provided does not match the address derived from the entropy", "addressMismatch"),
            (
                "Failed to derive address from decrypted private key. Ensure your private key was encrypted as raw bytes.",
                "invalidPrivateKey"
            ),
            (
                "Failed to derive Solana keypair from decrypted private key. Ensure your private key was encrypted as raw bytes.",
                "invalidPrivateKey"
            ),
            (
                "Failed to derive address from decrypted seed phrase. Ensure you are importing a bip39 seed phrase.",
                "invalidSeedPhrase"
            ),
        ]
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        for (message, reason) in cases {
            testWalletApiRepository.submitImportResult = .failure(Self.invalidDataError(message))

            await XCTAssertThrowsErrorAsync(
                try await service.importWallet(.privateKey(Self.ethereumPrivateKey), chainType: .ethereum, address: Self.ethereumAddress)
            ) { error in
                Self.assertReason(error, is: reason)
            }
        }
    }

    internal func testOtherServerErrorsMapToImportFailedWithTheServerMessage() async {
        let message = "Failed to decrypt ciphertext with HPKE."
        testWalletApiRepository.submitImportResult = .failure(Self.invalidDataError(message))
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        await XCTAssertThrowsErrorAsync(
            try await service.importWallet(.privateKey(Self.ethereumPrivateKey), chainType: .ethereum, address: Self.ethereumAddress)
        ) { error in
            guard case .embeddedWalletFailure(.importFailed(let failureMessage)) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .importFailed, got \(error)")
            }
            XCTAssertTrue(failureMessage.contains(message))
        }
    }

    internal func testCancellationIsReportedAsCancelled() async {
        testWalletApiRepository.initImportResult = .failure(CancellationError())
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        await XCTAssertThrowsErrorAsync(
            try await service.importWallet(.privateKey(Self.ethereumPrivateKey), chainType: .ethereum, address: Self.ethereumAddress)
        ) { error in
            XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)")
        }

        XCTAssertEqual(testBreadcrumbEmitter.emitted.map(\.event), ["wallet.import.started", "wallet.import.failed"])
        XCTAssertEqual(testBreadcrumbEmitter.emitted.last?.data["error"], "cancelled")
    }

    internal func testFailsIfTheImportedWalletIsMissingAfterRefresh() async {
        testAuthManager.stubSession(refreshedLinkedAccounts: [])
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        await XCTAssertThrowsErrorAsync(
            try await service.importWallet(.privateKey(Self.ethereumPrivateKey), chainType: .ethereum, address: Self.ethereumAddress)
        ) { error in
            Self.assertReason(error, is: "importFailed")
        }
    }

    internal func testFailsWithoutRefreshingTheSessionIfTheUserRefreshFails() async {
        testAuthManager.stubSession(refreshedLinkedAccounts: [])
        testAuthManager.refreshUserResult = .failure(ApiError.apiError(httpCode: 500, errorCode: "server_error", description: "Internal error"))
        let service: WalletImportService = resolve(\PrivyContainer.walletImportService)

        // `refreshSession` isn't stubbed, so calling it would fail the test
        await XCTAssertThrowsErrorAsync(
            try await service.importWallet(.privateKey(Self.ethereumPrivateKey), chainType: .ethereum, address: Self.ethereumAddress)
        ) { error in
            Self.assertReason(error, is: "importFailed")
        }

        XCTAssertEqual(testWalletApiRepository.submitImportRequests.count, 1)
    }

    // MARK: - Helpers

    private static func invalidDataError(_ message: String) -> ApiError {
        ApiError.apiError(httpCode: 400, errorCode: "invalid_data", description: message)
    }

    private static func importedEthereumWallet() -> LinkedAccount {
        .embeddedEthereumWallet(
            EmbeddedEthereumWalletAccount(
                id: walletId,
                address: ethereumAddress,
                recoveryMethod: "privy-v2",
                firstVerifiedAt: nil,
                latestVerifiedAt: nil,
                hdWalletIndex: 0,
                imported: true,
                userCanSign: true
            )
        )
    }

    private static func importedSolanaWallet() -> LinkedAccount {
        .embeddedSolanaWallet(
            EmbeddedSolanaWalletAccount(
                id: walletId,
                address: solanaAddress,
                recoveryMethod: "privy-v2",
                firstVerifiedAt: nil,
                latestVerifiedAt: nil,
                hdWalletIndex: 0,
                imported: true,
                userCanSign: true
            )
        )
    }

    private static func assertReason(_ error: Error, is breadcrumbCode: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let privyError = error as? PrivyError else {
            return XCTFail("Expected a PrivyError, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(privyError.breadcrumbCode, "embeddedWalletFailure.\(breadcrumbCode)", file: file, line: line)
    }
}
