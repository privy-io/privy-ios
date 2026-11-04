import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class LoginWithSmsImplTests: PrivyTestCase {
    private struct StubError: Error {}

    private var testAuthManager: TestAuthManager!
    private var loginWithSms: LoginWithSms!

    override internal func setUp() {
        super.setUp()
        let testAuthManager = TestAuthManager()
        testAuthManager.ensureAuthenticatedResult = .success(.test())
        register(\PrivyContainer.authManager) { testAuthManager }
        self.testAuthManager = testAuthManager
        self.loginWithSms = resolve(\PrivyContainer.loginWithSms)
    }

    // MARK: sendCode

    internal func testSendCodeSucceeds() async throws {
        try await loginWithSms.sendCode(to: "+15555550100")

        XCTAssertEqual(testAuthManager.sendOtpRequests, [.phone("+15555550100")])
    }

    internal func testSendCodePropagatesFailure() async {
        testAuthManager.sendOtpResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSms.sendCode(to: "+15555550100")) { error in
            XCTAssertTrue(error is StubError)
        }
    }

    // MARK: loginWithCode

    internal func testLoginWithCodeSucceeds() async throws {
        testAuthManager.loginResult = .success(TestPrivyUser(id: "logged-in-user"))

        let user = try await loginWithSms.loginWithCode("123456", sentTo: "+15555550100")

        XCTAssertEqual(user.id, "logged-in-user")
        guard case .phone(let phoneNumber, let code) = testAuthManager.loginRequests.first else {
            return XCTFail("Expected a .phone login request")
        }
        XCTAssertEqual(phoneNumber, "+15555550100")
        XCTAssertEqual(code, "123456")
    }

    internal func testLoginWithCodeMapsIncorrectOtpTo422() async {
        testAuthManager.loginResult = .failure(ApiError.networkError(responseCode: 422))

        await XCTAssertThrowsErrorAsync(try await loginWithSms.loginWithCode("000000", sentTo: "+15555550100")) { error in
            guard case .authenticationFailure(.incorrectCredentials(let loginMethod)) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.incorrectCredentials), got \(error)")
            }
            XCTAssertEqual(loginMethod, .phone)
        }
    }

    internal func testLoginWithCodePassesThroughTypedPrivyError() async {
        testAuthManager.loginResult = .failure(PrivyError(.authenticationFailure(reason: .sessionExpired)))

        await XCTAssertThrowsErrorAsync(try await loginWithSms.loginWithCode("123456", sentTo: "+15555550100")) { error in
            guard case .authenticationFailure(.sessionExpired) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.sessionExpired), got \(error)")
            }
        }
    }

    internal func testLoginWithCodeWrapsUnknownErrors() async {
        testAuthManager.loginResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSms.loginWithCode("123456", sentTo: "+15555550100")) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }

    // MARK: linkWithCode

    internal func testLinkWithCodeSucceeds() async throws {
        testAuthManager.linkAccountResult = .success(TestPrivyUser(id: "linked-user"))

        let user = try await loginWithSms.linkWithCode("123456", sentTo: "+15555550100")

        XCTAssertEqual(user.id, "linked-user")
        guard case .phone(let phoneNumber, let code) = testAuthManager.linkAccountRequests.first else {
            return XCTFail("Expected a .phone link request")
        }
        XCTAssertEqual(phoneNumber, "+15555550100")
        XCTAssertEqual(code, "123456")
    }

    internal func testLinkWithCodeRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSms.linkWithCode("123456", sentTo: "+15555550100")) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.linkAccountRequests.isEmpty)
    }

    internal func testLinkWithCodeMapsIncorrectOtpTo422() async {
        testAuthManager.linkAccountResult = .failure(ApiError.networkError(responseCode: 422))

        await XCTAssertThrowsErrorAsync(try await loginWithSms.linkWithCode("000000", sentTo: "+15555550100")) { error in
            guard case .authenticationFailure(.incorrectCredentials(let loginMethod)) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.incorrectCredentials), got \(error)")
            }
            XCTAssertEqual(loginMethod, .phone)
        }
    }

    // MARK: updateWithCode

    internal func testUpdateWithCodeSucceeds() async throws {
        try await loginWithSms.updateWithCode("123456", sentTo: "+15555550100")

        XCTAssertEqual(testAuthManager.updatePhoneNumberRequests.count, 1)
        XCTAssertEqual(testAuthManager.updatePhoneNumberRequests.first?.phoneNumber, "+15555550100")
        XCTAssertEqual(testAuthManager.updatePhoneNumberRequests.first?.code, "123456")
    }

    internal func testUpdateWithCodeRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSms.updateWithCode("123456", sentTo: "+15555550100")) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.updatePhoneNumberRequests.isEmpty)
    }

    internal func testUpdateWithCodePropagatesFailure() async {
        testAuthManager.updatePhoneNumberResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSms.updateWithCode("123456", sentTo: "+15555550100")) { error in
            XCTAssertTrue(error is StubError)
        }
    }

    // MARK: unlink

    internal func testUnlinkSucceeds() async throws {
        testAuthManager.unlinkAccountResult = .success(TestPrivyUser(id: "unlinked-user"))

        let user = try await loginWithSms.unlink(phoneNumber: "+15555550100")

        XCTAssertEqual(user.id, "unlinked-user")
        guard case .phone(let phoneNumber) = testAuthManager.unlinkAccountRequests.first else {
            return XCTFail("Expected a .phone unlink request")
        }
        XCTAssertEqual(phoneNumber, "+15555550100")
    }

    internal func testUnlinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSms.unlink(phoneNumber: "+15555550100")) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.unlinkAccountRequests.isEmpty)
    }

    // MARK: transferWithCode

    internal func testTransferWithCodeSucceeds() async throws {
        testAuthManager.transferAccountResult = .success(TestPrivyUser(id: "transferred-user"))

        let user = try await loginWithSms.transferWithCode(nonce: "test-nonce", code: "123456", sentTo: "+15555550100")

        XCTAssertEqual(user.id, "transferred-user")
        guard case .phone(let phoneNumber, let code, let nonce) = testAuthManager.transferAccountRequests.first else {
            return XCTFail("Expected a .phone transfer request")
        }
        XCTAssertEqual(phoneNumber, "+15555550100")
        XCTAssertEqual(code, "123456")
        XCTAssertEqual(nonce, "test-nonce")
    }

    internal func testTransferWithCodeRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSms.transferWithCode(nonce: "n", code: "123456", sentTo: "+15555550100")) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.transferAccountRequests.isEmpty)
    }

    internal func testTransferWithCodeWrapsUnknownErrors() async {
        testAuthManager.transferAccountResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithSms.transferWithCode(nonce: "n", code: "123456", sentTo: "+15555550100")) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }
}
