import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class LoginWithSiwsImplTests: PrivyTestCase {
    private struct StubError: Error {}

    private let params = SiwsMessageParams(domain: "example.com", uri: "https://example.com", address: "SoLaNaAddress")
    private let metadata = WalletLoginMetadata(walletClientType: .other, connectorType: "wallet_connect")

    private var testAuthManager: TestAuthManager!
    private var loginWithSiws: LoginWithSiws!

    override internal func setUp() {
        super.setUp()
        let testAuthManager = TestAuthManager()
        testAuthManager.ensureAuthenticatedResult = .success(.test())
        register(\PrivyContainer.authManager) { testAuthManager }
        self.testAuthManager = testAuthManager
        self.loginWithSiws = resolve(\PrivyContainer.loginWithSiws)
    }

    // MARK: generateMessage

    internal func testGenerateMessageEmbedsServerAddressAndNonce() async throws {
        testAuthManager.generateSiwsMessageResult = .success(.test(nonce: "server-nonce", address: "ServerAddress"))

        let message = try await loginWithSiws.generateMessage(params: params)

        XCTAssertEqual(testAuthManager.generateSiwsMessageRequests, ["SoLaNaAddress"])
        XCTAssertTrue(message.hasPrefix("example.com wants you to sign in with your Solana account:\nServerAddress\n"))
        XCTAssertTrue(message.contains("You are proving you own ServerAddress."))
        XCTAssertTrue(message.contains("URI: https://example.com"))
        XCTAssertTrue(message.contains("Nonce: server-nonce"))
        XCTAssertTrue(message.contains("Issued At: "))
    }

    internal func testGenerateMessageWrapsFailures() async {
        testAuthManager.generateSiwsMessageResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiws.generateMessage(params: params)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }

    // MARK: login

    internal func testLoginSucceedsAndForwardsArguments() async throws {
        testAuthManager.loginWithSiwsResult = .success(TestPrivyUser(id: "logged-in-user"))

        let user = try await loginWithSiws.login(message: "msg", signature: "sig", params: params, metadata: metadata)

        XCTAssertEqual(user.id, "logged-in-user")
        let request = try XCTUnwrap(testAuthManager.loginWithSiwsRequests.first)
        XCTAssertEqual(request.address, "SoLaNaAddress")
        XCTAssertEqual(request.message, "msg")
        XCTAssertEqual(request.signature, "sig")
        XCTAssertEqual(request.metadata?.walletClientType, .other)
        XCTAssertEqual(request.metadata?.connectorType, "wallet_connect")
    }

    internal func testLoginWithoutParamsSendsNilAddress() async throws {
        _ = try await loginWithSiws.login(message: "msg", signature: "sig")

        let request = try XCTUnwrap(testAuthManager.loginWithSiwsRequests.first)
        XCTAssertNil(request.address)
        XCTAssertNil(request.metadata)
    }

    internal func testLoginPassesThroughTypedPrivyError() async {
        testAuthManager.loginWithSiwsResult = .failure(PrivyError(.authenticationFailure(reason: .sessionExpired)))

        await XCTAssertThrowsErrorAsync(try await loginWithSiws.login(message: "m", signature: "s")) { error in
            guard case .authenticationFailure(.sessionExpired) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.sessionExpired), got \(error)")
            }
        }
    }

    internal func testLoginWrapsUnknownErrors() async {
        testAuthManager.loginWithSiwsResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiws.login(message: "m", signature: "s")) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }

    // MARK: link

    internal func testLinkSucceedsAndForwardsArguments() async throws {
        testAuthManager.linkWithSiwsResult = .success(TestPrivyUser(id: "linked-user"))

        let user = try await loginWithSiws.link(message: "msg", signature: "sig", params: params, metadata: metadata)

        XCTAssertEqual(user.id, "linked-user")
        let request = try XCTUnwrap(testAuthManager.linkWithSiwsRequests.first)
        XCTAssertEqual(request.address, "SoLaNaAddress")
        XCTAssertEqual(request.message, "msg")
        XCTAssertEqual(request.signature, "sig")
        XCTAssertEqual(request.metadata?.walletClientType, .other)
    }

    internal func testLinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(PrivyError(.authenticationFailure(reason: .notLoggedIn)))

        await XCTAssertThrowsErrorAsync(try await loginWithSiws.link(message: "m", signature: "s")) { error in
            guard case .authenticationFailure(.notLoggedIn) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.notLoggedIn), got \(error)")
            }
        }
        XCTAssertTrue(testAuthManager.linkWithSiwsRequests.isEmpty)
    }

    internal func testLinkWrapsUnknownErrors() async {
        testAuthManager.linkWithSiwsResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiws.link(message: "m", signature: "s")) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }

    // MARK: unlink

    internal func testUnlinkSucceeds() async throws {
        testAuthManager.unlinkSiwsWalletResult = .success(TestPrivyUser(id: "unlinked-user"))

        let user = try await loginWithSiws.unlink(address: "SoLaNaAddress")

        XCTAssertEqual(user.id, "unlinked-user")
        XCTAssertEqual(testAuthManager.unlinkSiwsWalletRequests, ["SoLaNaAddress"])
    }

    internal func testUnlinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSiws.unlink(address: "SoLaNaAddress")) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
        XCTAssertTrue(testAuthManager.unlinkSiwsWalletRequests.isEmpty)
    }

    // MARK: transferAccount

    internal func testTransferAccountSucceedsAndForwardsNonce() async throws {
        testAuthManager.transferAccountResult = .success(TestPrivyUser(id: "transferred-user"))

        let user = try await loginWithSiws.transferAccount(
            nonce: "transfer-nonce",
            message: "msg",
            signature: "sig",
            params: params,
            metadata: metadata
        )

        XCTAssertEqual(user.id, "transferred-user")
        guard case .siws(let message, let signature, let walletAddress, let walletClientType, let connectorType, let nonce) =
            testAuthManager.transferAccountRequests.first else {
            return XCTFail("Expected a .siws transfer request")
        }
        XCTAssertEqual(message, "msg")
        XCTAssertEqual(signature, "sig")
        XCTAssertEqual(walletAddress, "SoLaNaAddress")
        XCTAssertEqual(walletClientType, .other)
        XCTAssertEqual(connectorType, "wallet_connect")
        XCTAssertEqual(nonce, "transfer-nonce")
    }

    internal func testTransferAccountRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(
            try await loginWithSiws.transferAccount(nonce: "n", message: "m", signature: "s", params: params)
        ) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.transferAccountRequests.isEmpty)
    }

    internal func testTransferAccountPassesThroughTypedPrivyError() async {
        testAuthManager.transferAccountResult = .failure(PrivyError(.authenticationFailure(reason: .sessionExpired)))

        await XCTAssertThrowsErrorAsync(
            try await loginWithSiws.transferAccount(nonce: "n", message: "m", signature: "s", params: params)
        ) { error in
            guard case .authenticationFailure(.sessionExpired) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.sessionExpired), got \(error)")
            }
        }
    }

    internal func testTransferAccountWrapsUnknownErrors() async {
        testAuthManager.transferAccountResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(
            try await loginWithSiws.transferAccount(nonce: "n", message: "m", signature: "s", params: params)
        ) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }
}
