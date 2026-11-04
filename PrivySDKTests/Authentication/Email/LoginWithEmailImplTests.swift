import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class LoginWithEmailImplTests: PrivyTestCase {
    private var testAuthManager: TestAuthManager!
    private var loginWithEmail: LoginWithEmail!

    override internal func setUp() {
        super.setUp()
        let testAuthManager = TestAuthManager()
        register(\PrivyContainer.authManager) { testAuthManager }
        self.testAuthManager = testAuthManager
        self.loginWithEmail = resolve(\PrivyContainer.loginWithEmail)
    }

    internal func testSendCodeSucceeds() async throws {
        try await loginWithEmail.sendCode(to: "user@privy.io")

        XCTAssertEqual(testAuthManager.sendOtpRequests, [.email(email: "user@privy.io")])
    }

    internal func testSendCodePropagatesFailure() async {
        struct SendCodeError: Error {}
        testAuthManager.sendOtpResult = .failure(SendCodeError())

        await XCTAssertThrowsErrorAsync(try await loginWithEmail.sendCode(to: "user@privy.io")) { error in
            XCTAssertTrue(error is SendCodeError)
        }
    }

    internal func testLoginWithCodeSucceeds() async throws {
        testAuthManager.loginResult = .success(TestPrivyUser(id: "logged-in-user"))

        let user = try await loginWithEmail.loginWithCode("123456", sentTo: "user@privy.io")

        XCTAssertEqual(user.id, "logged-in-user")
        guard case .email(let email, let code) = testAuthManager.loginRequests.first else {
            return XCTFail("Expected an .email login request")
        }
        XCTAssertEqual(email, "user@privy.io")
        XCTAssertEqual(code, "123456")
    }

    internal func testLoginWithCodeMapsIncorrectOtpTo422() async {
        testAuthManager.loginResult = .failure(ApiError.networkError(responseCode: 422))

        await XCTAssertThrowsErrorAsync(try await loginWithEmail.loginWithCode("000000", sentTo: "user@privy.io")) { error in
            guard case .authenticationFailure(.incorrectCredentials(let loginMethod)) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.incorrectCredentials), got \(error)")
            }
            XCTAssertEqual(loginMethod, .email)
        }
    }

    internal func testLoginWithCodePassesThroughTypedPrivyError() async {
        let conflictingUser = ConflictingUserMetadata(
            embeddedWalletAddress: nil,
            farcasterEmbeddedAddress: nil,
            displayName: "conflicting@privy.io",
            oAuthUserInfo: nil
        )
        testAuthManager.loginResult = .failure(
            PrivyError(.authenticationFailure(reason: .accountTransferRequired(nonce: "test-nonce", conflictingUser: conflictingUser)))
        )

        await XCTAssertThrowsErrorAsync(try await loginWithEmail.loginWithCode("123456", sentTo: "user@privy.io")) { error in
            guard case .authenticationFailure(.accountTransferRequired(let nonce, _)) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.accountTransferRequired), got \(error)")
            }
            XCTAssertEqual(nonce, "test-nonce")
        }
    }

    internal func testLoginWithCodeWrapsUnknownErrors() async {
        struct UnknownError: Error {}
        testAuthManager.loginResult = .failure(UnknownError())

        await XCTAssertThrowsErrorAsync(try await loginWithEmail.loginWithCode("123456", sentTo: "user@privy.io")) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }
}
