import XCTest
@testable import Privy

final class PrivyTests: XCTestCase {
    func testConfigure() {
        Privy.shared.configure(config: PrivyConfig(appId: "1")) { "" }
        XCTAssertEqual(Privy.shared.config?.appId, "1")
    }

    func testLogin() async {
        do {
            let user = try await Privy.shared.loginWithCustomAccessToken()
            let authState = AuthState.authenticated(user, .connected(EmbeddedWalletProvider(chainId: "", rpcURL: "")))
            XCTAssertEqual(Privy.shared.authState, authState)
        } catch {

        }
    }
}
