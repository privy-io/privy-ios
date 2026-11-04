import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class LoginWithPasskeyImplTests: PrivyTestCase {
    private struct StubError: Error {}

    private let relyingParty = "https://example.com"

    private var testAuthManager: TestAuthManager!
    private var testPasskeyHandler: TestPasskeyHandler!
    private var loginWithPasskey: LoginWithPasskey!

    override internal func setUp() {
        super.setUp()
        let testAuthManager = TestAuthManager()
        testAuthManager.ensureAuthenticatedResult = .success(.test())
        let testPasskeyHandler = TestPasskeyHandler()
        register(\PrivyContainer.authManager) { testAuthManager }
        register(\PrivyContainer.passkeyHandler) { testPasskeyHandler }
        self.testAuthManager = testAuthManager
        self.testPasskeyHandler = testPasskeyHandler
        self.loginWithPasskey = resolve(\PrivyContainer.loginWithPasskey)
    }

    private func assertInvalidRelyingParty(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        guard case .authenticationFailure(.passkeyCreationFailed(let message)) = (error as? PrivyError)?.errorCode else {
            return XCTFail("Expected .authenticationFailure(.passkeyCreationFailed), got \(error)", file: file, line: line)
        }
        XCTAssertEqual(message, "Invalid relying party URL", file: file, line: line)
    }

    // MARK: signup

    internal func testSignupSucceeds() async throws {
        testAuthManager.generatePasskeyRegistrationOptionsResult = .success(.test(challenge: "signup-challenge"))
        testAuthManager.loginResult = .success(TestPrivyUser(id: "signed-up-user"))

        let user = try await loginWithPasskey.signup(relyingParty: relyingParty, displayName: "Display Name")

        XCTAssertEqual(user.id, "signed-up-user")
        XCTAssertEqual(testAuthManager.generatePasskeyRegistrationOptionsRequests, [URL(string: relyingParty)!])
        XCTAssertEqual(testPasskeyHandler.createCredentialRequests.first?.options.challenge, "signup-challenge")
        XCTAssertEqual(testPasskeyHandler.createCredentialRequests.first?.overrideDisplayName, "Display Name")
        guard case .passkeyRegistration(let credential, let sentRelyingParty) = testAuthManager.loginRequests.first else {
            return XCTFail("Expected a .passkeyRegistration login request")
        }
        XCTAssertEqual(credential.id, "test-credential-id")
        XCTAssertEqual(sentRelyingParty, relyingParty)
    }

    internal func testSignupAllowsHttpLocalhost() async throws {
        _ = try await loginWithPasskey.signup(relyingParty: "http://localhost:8080", displayName: nil)

        XCTAssertEqual(testAuthManager.generatePasskeyRegistrationOptionsRequests, [URL(string: "http://localhost:8080")!])
    }

    internal func testSignupRejectsInsecureRelyingParty() async {
        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.signup(relyingParty: "http://example.com", displayName: nil)) { error in
            self.assertInvalidRelyingParty(error)
        }
        XCTAssertTrue(testAuthManager.generatePasskeyRegistrationOptionsRequests.isEmpty)
    }

    internal func testSignupPropagatesOptionsFailure() async {
        testAuthManager.generatePasskeyRegistrationOptionsResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.signup(relyingParty: relyingParty, displayName: nil)) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testPasskeyHandler.createCredentialRequests.isEmpty)
    }

    internal func testSignupPropagatesCredentialCreationFailure() async {
        testPasskeyHandler.createCredentialResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.signup(relyingParty: relyingParty, displayName: nil)) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.loginRequests.isEmpty)
    }

    // MARK: login

    internal func testLoginSucceeds() async throws {
        testAuthManager.generatePasskeyAuthenticationOptionsResult = .success(.test(challenge: "login-challenge"))
        testAuthManager.loginResult = .success(TestPrivyUser(id: "logged-in-user"))

        let user = try await loginWithPasskey.login(relyingParty: relyingParty)

        XCTAssertEqual(user.id, "logged-in-user")
        XCTAssertEqual(testAuthManager.generatePasskeyAuthenticationOptionsRequests, [URL(string: relyingParty)!])
        XCTAssertEqual(testPasskeyHandler.getCredentialRequests.first?.challenge, "login-challenge")
        guard case .passkeyAuthentication(let credential, let challenge, let sentRelyingParty) = testAuthManager.loginRequests.first else {
            return XCTFail("Expected a .passkeyAuthentication login request")
        }
        XCTAssertEqual(credential.id, "test-credential-id")
        XCTAssertEqual(challenge, "login-challenge")
        XCTAssertEqual(sentRelyingParty, relyingParty)
    }

    internal func testLoginRejectsInvalidRelyingParty() async {
        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.login(relyingParty: "not a url")) { error in
            self.assertInvalidRelyingParty(error)
        }
        XCTAssertTrue(testAuthManager.generatePasskeyAuthenticationOptionsRequests.isEmpty)
    }

    internal func testLoginPropagatesCredentialRetrievalFailure() async {
        testPasskeyHandler.getCredentialResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.login(relyingParty: relyingParty)) { error in
            XCTAssertTrue(error is StubError)
        }
        XCTAssertTrue(testAuthManager.loginRequests.isEmpty)
    }

    internal func testLoginPropagatesAuthManagerFailure() async {
        testAuthManager.loginResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.login(relyingParty: relyingParty)) { error in
            XCTAssertTrue(error is StubError)
        }
    }

    // MARK: link

    internal func testLinkSucceeds() async throws {
        testAuthManager.generatePasskeyLinkOptionsResult = .success(.test(challenge: "link-challenge"))
        testAuthManager.linkPasskeyResult = .success(TestPrivyUser(id: "linked-user"))

        let user = try await loginWithPasskey.link(relyingParty: relyingParty, displayName: "Display Name")

        XCTAssertEqual(user.id, "linked-user")
        XCTAssertEqual(testAuthManager.generatePasskeyLinkOptionsRequests, [URL(string: relyingParty)!])
        XCTAssertEqual(testPasskeyHandler.createCredentialRequests.first?.options.challenge, "link-challenge")
        XCTAssertEqual(testPasskeyHandler.createCredentialRequests.first?.overrideDisplayName, "Display Name")
        XCTAssertEqual(testAuthManager.linkPasskeyRequests.first?.credential.id, "test-credential-id")
        XCTAssertEqual(testAuthManager.linkPasskeyRequests.first?.relyingParty, relyingParty)
    }

    internal func testLinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.link(relyingParty: relyingParty, displayName: nil)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
        XCTAssertTrue(testAuthManager.generatePasskeyLinkOptionsRequests.isEmpty)
    }

    internal func testLinkWrapsInvalidRelyingPartyError() async {
        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.link(relyingParty: "http://example.com", displayName: nil)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }

    internal func testLinkWrapsCredentialCreationFailure() async {
        testPasskeyHandler.createCredentialResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.link(relyingParty: relyingParty, displayName: nil)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
        XCTAssertTrue(testAuthManager.linkPasskeyRequests.isEmpty)
    }

    // MARK: unlink

    internal func testUnlinkSucceeds() async throws {
        testAuthManager.unlinkPasskeyResult = .success(TestPrivyUser(id: "unlinked-user"))

        let user = try await loginWithPasskey.unlink(credentialId: "credential-1", removeAsMfa: true)

        XCTAssertEqual(user.id, "unlinked-user")
        XCTAssertEqual(testAuthManager.unlinkPasskeyRequests.first?.credentialId, "credential-1")
        XCTAssertEqual(testAuthManager.unlinkPasskeyRequests.first?.removeAsMfa, true)
    }

    internal func testUnlinkRequiresAuthentication() async {
        testAuthManager.ensureAuthenticatedResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.unlink(credentialId: "credential-1", removeAsMfa: false)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
        XCTAssertTrue(testAuthManager.unlinkPasskeyRequests.isEmpty)
    }

    internal func testUnlinkWrapsAuthManagerFailure() async {
        testAuthManager.unlinkPasskeyResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await loginWithPasskey.unlink(credentialId: "credential-1", removeAsMfa: false)) { error in
            guard case .authenticationFailure(.failureDuringAuthentication) = (error as? PrivyError)?.errorCode else {
                return XCTFail("Expected .authenticationFailure(.failureDuringAuthentication), got \(error)")
            }
        }
    }
}
