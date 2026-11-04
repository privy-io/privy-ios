import XCTest
@testable import FactoryKit
@testable import PrivySDK

/// Base test case for Privy SDK unit tests. Extend this instead of `XCTestCase` directly.
///
/// `Impl` types resolve their dependencies via `resolve(\PrivyContainer.x)` inside their own
/// property initializers rather than through their `init`, so a fake has to be registered into
/// `PrivyContainer` *before* the type under test is constructed. `register` does that, and
/// `setUp`/`tearDown` reset the container around every test so an override never leaks into the
/// next one.
///
/// ```swift
/// final class LoginWithEmailImplTests: PrivyTestCase {
///     func testSendCodeSucceeds() async throws {
///         let testAuthManager = TestAuthManager()
///         register(\PrivyContainer.authManager) { testAuthManager }
///
///         let loginWithEmail: LoginWithEmail = resolve(\PrivyContainer.loginWithEmail)
///         try await loginWithEmail.sendCode(to: "user@privy.io")
///
///         XCTAssertEqual(testAuthManager.sendOtpRequests, [.email(email: "user@privy.io")])
///     }
/// }
/// ```
internal class PrivyTestCase: XCTestCase {
    override internal func setUp() {
        super.setUp()
        PrivyContainer.shared.manager.reset()
        PrivyContainer.shared.initialize(config: PrivyConfig(appId: "test-app-id", appClientId: "test-client-id"))
    }

    override internal func tearDown() {
        PrivyContainer.shared.manager.reset()
        super.tearDown()
    }

    /// Overrides a `PrivyContainer` factory for the duration of this test. Equivalent to calling
    /// `PrivyContainer.shared[keyPath: keyPath].register(factory:)` directly, named to make the
    /// test-only intent obvious at the call site.
    internal func register<T>(_ keyPath: KeyPath<PrivyContainer, Factory<T>>, factory: @escaping @Sendable () -> T) {
        PrivyContainer.shared[keyPath: keyPath].register(factory: factory)
    }
}
