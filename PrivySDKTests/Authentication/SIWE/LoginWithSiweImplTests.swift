import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class LoginWithSiweImplTests: PrivyTestCase {
    private struct StubError: Error {}

    private let params = SiweMessageParams(
        appDomain: "example.com",
        appUri: "https://example.com",
        chainId: "1",
        walletAddress: "0xabc"
    )
    private let metadata = WalletLoginMetadata(walletClientType: .metamask, connectorType: "wallet_connect")

    private var testAuthManager: TestAuthManager!
    private var loginWithSiwe: LoginWithSiwe!

    override internal func setUp() {
        super.setUp()
        let testAuthManager = TestAuthManager()
        testAuthManager.ensureAuthenticatedResult = .success(.test())
        register(\PrivyContainer.authManager) { testAuthManager }
        self.testAuthManager = testAuthManager
        self.loginWithSiwe = resolve(\PrivyContainer.loginWithSiwe)
    }

    // MARK: generateMessage

    internal func testGenerateMessageEmbedsParamsAndNonce() async throws {
        testAuthManager.generateSiweMessageResult = .success(.test(nonce: "server-nonce"))

        let message = try await loginWithSiwe.generateMessage(params: params)

        XCTAssertEqual(testAuthManager.generateSiweMessageRequests, ["0xabc"])
        XCTAssertTrue(message.hasPrefix("example.com wants you to sign in with your Ethereum account:\n0xabc\n"))
        XCTAssertTrue(message.contains("URI: https://example.com"))
        XCTAssertTrue(message.contains("Chain ID: 1"))
        XCTAssertTrue(message.contains("Nonce: server-nonce"))
        XCTAssertTrue(message.contains("Issued At: "))
    }

    internal func testGenerateSiweMessageMatchesGenerateMessage() async throws {
        let message = try await loginWithSiwe.generateSiweMessage(params: params)

        XCTAssertEqual(testAuthManager.generateSiweMessageRequests, ["0xabc"])
        XCTAssertTrue(message.contains("Nonce: test-nonce"))
    }

    internal func testGenerateMessageWrapsFailures() async {
        testAuthManager.generateSiweMessageResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiwe.generateMessage(params: params)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }

    // MARK: login

    internal func testLoginSucceedsAndForwardsSiweParams() async throws {
        testAuthManager.loginResult = .success(TestPrivyUser(id: "logged-in-user"))

        let user = try await loginWithSiwe.login(message: "msg", signature: "sig", params: params, metadata: metadata)

        XCTAssertEqual(user.id, "logged-in-user")
        guard case .siwe(let siweParams) = testAuthManager.loginRequests.first else {
            return XCTFail("Expected a .siwe login request")
        }
        XCTAssertEqual(siweParams.message, "msg")
        XCTAssertEqual(siweParams.signature, "sig")
        XCTAssertEqual(siweParams.chainId, "1")
        XCTAssertEqual(siweParams.walletAddress, "0xabc")
        XCTAssertEqual(siweParams.walletClientType, .metamask)
        XCTAssertEqual(siweParams.connectorType, "wallet_connect")
    }

    internal func testLoginWithoutMetadataLeavesWalletTypesNil() async throws {
        _ = try await loginWithSiwe.login(message: "msg", signature: "sig", params: params, metadata: nil)

        guard case .siwe(let siweParams) = testAuthManager.loginRequests.first else {
            return XCTFail("Expected a .siwe login request")
        }
        XCTAssertNil(siweParams.walletClientType)
        XCTAssertNil(siweParams.connectorType)
    }

    internal func testLoginWithSiweAliasForwardsToLogin() async throws {
        _ = try await loginWithSiwe.loginWithSiwe(message: "msg", signature: "sig", params: params, metadata: nil)

        XCTAssertEqual(testAuthManager.loginRequests.count, 1)
    }

    internal func testLoginPassesThroughTypedPrivyError() async {
        testAuthManager.loginResult = .failure(PrivyError(.authenticationFailure(reason: .sessionExpired)))

        await XCTAssertThrowsErrorAsync(try await loginWithSiwe.login(message: "m", signature: "s", params: params, metadata: nil)) { error in
            guard case .authenticationFailure(.sessionExpired) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.sessionExpired), got \(error)")
            }
        }
    }

    internal func testLoginWrapsUnknownErrors() async {
        testAuthManager.loginResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiwe.login(message: "m", signature: "s", params: params, metadata: nil)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }

    // MARK: link

    internal func testLinkSucceedsAndForwardsSiweParams() async throws {
        testAuthManager.linkAccountResult = .success(TestPrivyUser(id: "linked-user"))

        let user = try await loginWithSiwe.link(message: "msg", signature: "sig", params: params, metadata: metadata)

        XCTAssertEqual(user.id, "linked-user")
        guard case .siwe(let siweParams) = testAuthManager.linkAccountRequests.first else {
            return XCTFail("Expected a .siwe link request")
        }
        XCTAssertEqual(siweParams.message, "msg")
        XCTAssertEqual(siweParams.walletAddress, "0xabc")
        XCTAssertEqual(siweParams.walletClientType, .metamask)
    }

    internal func testLinkWithSiweAliasForwardsToLink() async throws {
        _ = try await loginWithSiwe.linkWithSiwe(message: "msg", signature: "sig", params: params, metadata: nil)

        XCTAssertEqual(testAuthManager.linkAccountRequests.count, 1)
    }

    internal func testLinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiwe.link(message: "m", signature: "s", params: params, metadata: nil)) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.linkAccountRequests.isEmpty)
    }

    internal func testLinkWrapsUnknownErrors() async {
        testAuthManager.linkAccountResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiwe.link(message: "m", signature: "s", params: params, metadata: nil)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }

    // MARK: unlink

    internal func testUnlinkSucceeds() async throws {
        testAuthManager.unlinkAccountResult = .success(TestPrivyUser(id: "unlinked-user"))

        let user = try await loginWithSiwe.unlink(address: "0xabc")

        XCTAssertEqual(user.id, "unlinked-user")
        guard case .siwe(let address) = testAuthManager.unlinkAccountRequests.first else {
            return XCTFail("Expected a .siwe unlink request")
        }
        XCTAssertEqual(address, "0xabc")
    }

    internal func testUnlinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiwe.unlink(address: "0xabc")) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.unlinkAccountRequests.isEmpty)
    }

    // MARK: transferAccount

    internal func testTransferAccountSucceedsAndForwardsNonce() async throws {
        testAuthManager.transferAccountResult = .success(TestPrivyUser(id: "transferred-user"))

        let user = try await loginWithSiwe.transferAccount(
            nonce: "transfer-nonce",
            message: "msg",
            signature: "sig",
            params: params,
            metadata: metadata
        )

        XCTAssertEqual(user.id, "transferred-user")
        guard case .siwe(let siweParams, let nonce) = testAuthManager.transferAccountRequests.first else {
            return XCTFail("Expected a .siwe transfer request")
        }
        XCTAssertEqual(nonce, "transfer-nonce")
        XCTAssertEqual(siweParams.message, "msg")
        XCTAssertEqual(siweParams.signature, "sig")
        XCTAssertEqual(siweParams.chainId, "1")
        XCTAssertEqual(siweParams.walletAddress, "0xabc")
        XCTAssertEqual(siweParams.walletClientType, .metamask)
        XCTAssertEqual(siweParams.connectorType, "wallet_connect")
    }

    internal func testTransferAccountRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(
            try await loginWithSiwe.transferAccount(nonce: "n", message: "m", signature: "s", params: params, metadata: nil)
        ) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.transferAccountRequests.isEmpty)
    }

    internal func testTransferAccountPassesThroughTypedPrivyError() async {
        testAuthManager.transferAccountResult = .failure(PrivyError(.authenticationFailure(reason: .sessionExpired)))

        await XCTAssertThrowsErrorAsync(
            try await loginWithSiwe.transferAccount(nonce: "n", message: "m", signature: "s", params: params, metadata: nil)
        ) { error in
            guard case .authenticationFailure(.sessionExpired) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.sessionExpired), got \(error)")
            }
        }
    }

    internal func testTransferAccountWrapsUnknownErrors() async {
        testAuthManager.transferAccountResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(
            try await loginWithSiwe.transferAccount(nonce: "n", message: "m", signature: "s", params: params, metadata: nil)
        ) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }
}
