import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class PrivyUserImplTests: PrivyTestCase {
    private var testAuthManager: TestAuthManager!
    private var testWalletImportService: TestWalletImportService!
    private var privyUser: PrivyUser!

    override internal func setUp() {
        super.setUp()
        let testAuthManager = TestAuthManager()
        let testWalletImportService = TestWalletImportService()
        register(\PrivyContainer.authManager) { testAuthManager }
        register(\PrivyContainer.walletImportService) { testWalletImportService }
        self.testAuthManager = testAuthManager
        self.testWalletImportService = testWalletImportService
        self.privyUser = resolve(\PrivyContainer.privyUser)
    }

    // MARK: - userCanSign

    internal func testLinkedAccountsExposeUserCanSign() throws {
        try authenticate(with: Self.userWithEmbeddedWallets())

        let linkedAccounts = privyUser.linkedAccounts
        let ethereumAccounts = linkedAccounts.compactMap { account -> WalletUserCanSign? in
            guard case .embeddedEthereumWallet(let wallet) = account else { return nil }
            return WalletUserCanSign(address: wallet.address, userCanSign: wallet.userCanSign)
        }
        let solanaAccounts = linkedAccounts.compactMap { account -> WalletUserCanSign? in
            guard case .embeddedSolanaWallet(let wallet) = account else { return nil }
            return WalletUserCanSign(address: wallet.address, userCanSign: wallet.userCanSign)
        }

        XCTAssertEqual(linkedAccounts.count, 8)
        XCTAssertEqual(ethereumAccounts, Self.expectedEthereumWallets)
        XCTAssertEqual(solanaAccounts, Self.expectedSolanaWallets)
    }

    internal func testEmbeddedEthereumWalletsExposeUserCanSign() throws {
        try authenticate(with: Self.userWithEmbeddedWallets())

        let wallets = privyUser.embeddedEthereumWallets.map { wallet in
            WalletUserCanSign(address: wallet.address, userCanSign: wallet.userCanSign)
        }

        XCTAssertEqual(wallets, Self.expectedEthereumWallets)
    }

    internal func testEmbeddedSolanaWalletsExposeUserCanSign() throws {
        try authenticate(with: Self.userWithEmbeddedWallets())

        let wallets = privyUser.embeddedSolanaWallets.map { wallet in
            WalletUserCanSign(address: wallet.address, userCanSign: wallet.userCanSign)
        }

        XCTAssertEqual(wallets, Self.expectedSolanaWallets)
    }

    // MARK: - imported

    internal func testLinkedAccountsExposeImported() throws {
        try authenticate(with: Self.userWithEmbeddedWallets(imported: Self.importedResponses))

        let linkedAccounts = privyUser.linkedAccounts
        let ethereumImported = linkedAccounts.compactMap { account -> Bool? in
            guard case .embeddedEthereumWallet(let wallet) = account else { return nil }
            return wallet.imported
        }
        let solanaImported = linkedAccounts.compactMap { account -> Bool? in
            guard case .embeddedSolanaWallet(let wallet) = account else { return nil }
            return wallet.imported
        }

        XCTAssertEqual(ethereumImported, Self.expectedImported)
        XCTAssertEqual(solanaImported, Self.expectedImported)
    }

    internal func testEmbeddedEthereumWalletsExposeImported() throws {
        try authenticate(with: Self.userWithEmbeddedWallets(imported: Self.importedResponses))

        let imported = privyUser.embeddedEthereumWallets.map { $0.imported }

        XCTAssertEqual(imported, Self.expectedImported)
    }

    internal func testEmbeddedSolanaWalletsExposeImported() throws {
        try authenticate(with: Self.userWithEmbeddedWallets(imported: Self.importedResponses))

        let imported = privyUser.embeddedSolanaWallets.map { $0.imported }

        XCTAssertEqual(imported, Self.expectedImported)
    }

    // MARK: - importWallet

    internal func testImportWalletReturnsAnEthereumWalletForEthereum() async throws {
        let address = "0x" + String(repeating: "aB", count: 20)
        testWalletImportService.importWalletResult = .success(
            EmbeddedEthereumWalletAccount(
                id: "imported-wallet-id",
                address: address,
                recoveryMethod: "privy-v2",
                firstVerifiedAt: nil,
                latestVerifiedAt: nil,
                hdWalletIndex: 0,
                imported: true,
                userCanSign: true
            )
        )

        let wallet = try await privyUser.importWallet(chainType: .ethereum, address: address, secret: .privateKey(Data(repeating: 0x11, count: 32)))

        let ethereumWallet = try XCTUnwrap(wallet as? EmbeddedEthereumWallet)
        XCTAssertEqual(ethereumWallet.id, "imported-wallet-id")
        XCTAssertEqual(ethereumWallet.address, address)
        XCTAssertTrue(ethereumWallet.imported)
        XCTAssertEqual(testWalletImportService.importWalletRequests.first?.chainType, .ethereum)
        XCTAssertEqual(testWalletImportService.importWalletRequests.first?.address, address)
    }

    internal func testImportWalletReturnsASolanaWalletForSolana() async throws {
        let address = "So11111111111111111111111111111111111111112"
        testWalletImportService.importWalletResult = .success(
            EmbeddedSolanaWalletAccount(
                id: "imported-wallet-id",
                address: address,
                recoveryMethod: "privy-v2",
                firstVerifiedAt: nil,
                latestVerifiedAt: nil,
                hdWalletIndex: 0,
                imported: true,
                userCanSign: true
            )
        )

        let wallet = try await privyUser.importWallet(chainType: .solana, address: address, secret: .privateKey(Data(repeating: 0x22, count: 64)))

        let solanaWallet = try XCTUnwrap(wallet as? EmbeddedSolanaWallet)
        XCTAssertEqual(solanaWallet.address, address)
        XCTAssertEqual(solanaWallet.chainType, .solana)
        XCTAssertEqual(testWalletImportService.importWalletRequests.first?.chainType, .solana)
    }

    // MARK: - Helpers

    /// Maps `userResponse` the same way the SDK does after an API call, then makes it the
    /// authenticated user.
    private func authenticate(with userResponse: UserResponse) {
        testAuthManager.ensureAuthenticatedResult = .success(
            InternalAuthSession(
                user: userResponse.toPrivyUser(),
                authToken: "test-auth-token",
                refreshToken: "test-refresh-token",
                identityToken: nil,
                loginMethod: .email
            )
        )
    }
}

// MARK: - Fixtures

private struct WalletUserCanSign: Equatable {
    internal let address: String
    internal let userCanSign: Bool
}

private extension PrivyUserImplTests {
    static let expectedEthereumWallets = [
        WalletUserCanSign(address: "0x1111111111111111111111111111111111111111", userCanSign: true),
        WalletUserCanSign(address: "0x1234567890abcdef1234567890abcdef12345678", userCanSign: false),
        WalletUserCanSign(address: "0x1234567890123456789012345678901234567891", userCanSign: true),
    ]

    static let expectedSolanaWallets = [
        WalletUserCanSign(address: "SoLanaWa11etA111111111111111111111111111111", userCanSign: false),
        WalletUserCanSign(address: "SoLanaWa11etB111111111111111111111111111111", userCanSign: true),
        WalletUserCanSign(address: "SoLanaWa11etC111111111111111111111111111111", userCanSign: false),
    ]

    /// The `imported` values sent for each chain's embedded wallets, in order. A missing value
    /// means the wallet wasn't imported.
    static let importedResponses: [Bool?] = [true, false, nil]
    static let expectedImported = [true, false, false]

    /// A user object as returned by the API: an email account, an external wallet, and the
    /// embedded wallets above. The external wallet must not show up as an embedded wallet.
    ///
    /// - Parameters:
    ///   - imported: The `imported` value sent for the embedded wallet at each index, on both chains.
    static func userWithEmbeddedWallets(imported: [Bool?] = [false, false, false]) throws -> UserResponse {
        let ethereumWallets = expectedEthereumWallets.enumerated().map { index, wallet in
            embeddedWallet(wallet, chainType: "ethereum", index: index, imported: imported[index])
        }
        let solanaWallets = expectedSolanaWallets.enumerated().map { index, wallet in
            embeddedWallet(wallet, chainType: "solana", index: index, imported: imported[index])
        }
        let externalWallet = WalletAccountResponse(
            id: nil,
            address: "0x0000000000000000000000000000000000000000",
            chainType: "ethereum",
            chainId: "eip155:1",
            walletClientType: "metamask",
            connectorType: "injected",
            recoveryMethod: nil,
            firstVerifiedAt: nil,
            latestVerifiedAt: nil,
            hdWalletIndex: nil,
            imported: nil,
            rawUserCanSign: nil
        )

        return UserResponse(
            id: "did:privy:test-user-id",
            createdAt: try JSONDecoder().decode(SecondsSinceEpoch.self, from: Data("1700000000".utf8)),
            linkedAccounts: [
                .email(EmailAccountResponse(email: "user@privy.io", firstVerifiedAt: nil, latestVerifiedAt: nil)),
                .wallet(externalWallet),
            ] + ethereumWallets + solanaWallets,
            mfaMethods: []
        )
    }

    static func embeddedWallet(
        _ wallet: WalletUserCanSign,
        chainType: String,
        index: Int,
        imported: Bool? = false
    ) -> LinkedAccountResponse {
        .wallet(
            WalletAccountResponse(
                id: "\(chainType)-wallet-\(index)",
                address: wallet.address,
                chainType: chainType,
                chainId: nil,
                walletClientType: "privy",
                connectorType: "embedded",
                recoveryMethod: "privy-v2",
                firstVerifiedAt: nil,
                latestVerifiedAt: nil,
                hdWalletIndex: index,
                imported: imported,
                rawUserCanSign: wallet.userCanSign
            )
        )
    }
}
