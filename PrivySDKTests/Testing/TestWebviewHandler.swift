import Foundation
@testable import PrivySDK

/// In-memory `WebviewHandler` test double. Only the wallet create members are stubbable today;
/// every other member, and a create member whose result is left `nil`, fatal-errors if a test
/// exercises it.
internal final class TestWebviewHandler: WebviewHandler, @unchecked Sendable {
    internal var createEthereumWalletResult: Result<CreateEthereumWalletResponse, Error>?
    internal private(set) var createEthereumWalletRequests: [CreateEthereumWalletRequestData] = []

    internal var createSolanaWalletResult: Result<CreateSolanaWalletResponse, Error>?
    internal private(set) var createSolanaWalletRequests: [CreateSolanaWalletRequestData] = []

    internal var createAdditionalWalletResult: Result<ChainAgnosticCreateAdditionalWalletResponse, Error>?
    internal private(set) var createAdditionalWalletRequests: [ChainAgnosticCreateAdditionalWalletRequestData] = []

    internal var isWebViewInitialized: Bool {
        get async { notStubbed("isWebViewInitialized") }
    }

    internal func reloadWebView() async { notStubbed("reloadWebView") }

    internal func reinitializeWebView() async { notStubbed("reinitializeWebView") }

    internal func awaitReady(timeout: Duration) async throws { notStubbed("awaitReady") }

    internal func createEthereumWallet(data: CreateEthereumWalletRequestData, timeout: Duration) async throws -> CreateEthereumWalletResponse {
        guard let createEthereumWalletResult else { notStubbed("createEthereumWallet") }
        createEthereumWalletRequests.append(data)
        return try createEthereumWalletResult.get()
    }

    internal func createSolanaWallet(data: CreateSolanaWalletRequestData, timeout: Duration) async throws -> CreateSolanaWalletResponse {
        guard let createSolanaWalletResult else { notStubbed("createSolanaWallet") }
        createSolanaWalletRequests.append(data)
        return try createSolanaWalletResult.get()
    }

    internal func createAdditionalWallet(
        data: ChainAgnosticCreateAdditionalWalletRequestData,
        timeout: Duration
    ) async throws -> ChainAgnosticCreateAdditionalWalletResponse {
        guard let createAdditionalWalletResult else { notStubbed("createAdditionalWallet") }
        createAdditionalWalletRequests.append(data)
        return try createAdditionalWalletResult.get()
    }

    internal func connect(data: ChainAgnosticWalletConnectRequestData) async throws -> ChainAgnosticWalletConnectResponse {
        notStubbed("connect")
    }

    internal func recover(data: ChainAgnosticWalletRecoverRequestData, timeout: Duration) async throws -> WalletRecoverResponse {
        notStubbed("recover")
    }

    internal func rpc<T: Encodable>(data: WalletRpcRequestData<T>) async throws -> WalletRpcResponse {
        notStubbed("rpc")
    }

    internal func setPassword(data: WalletSetPasswordRequestData) async throws -> WalletSetPasswordResponse {
        notStubbed("setPassword")
    }

    internal func signWithUserSigner(data: UserSignerSignRequestData) async throws -> UserSignerSignResponse {
        notStubbed("signWithUserSigner")
    }

    internal func delegateActions(data: DelegateActionsRequestData) async throws -> DelegateActionsResponse {
        notStubbed("delegateActions")
    }

    internal func setMfaToken(data: MfaSetTokenRequestData) async throws -> MfaSetTokenResponse {
        notStubbed("setMfaToken")
    }

    internal func clearMfa(data: ClearMfaRequestData) async throws -> ClearMfaResponse {
        notStubbed("clearMfa")
    }

    private func notStubbed(_ member: String) -> Never {
        fatalError("TestWebviewHandler.\(member) was called but isn't stubbed for this test.")
    }
}
