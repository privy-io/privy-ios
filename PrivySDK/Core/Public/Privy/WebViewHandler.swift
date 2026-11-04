import Foundation
import WebKit
internal import FactoryKit
@preconcurrency import Combine

extension PrivyContainer {
    internal var webViewHandler: Factory<WebviewHandler> {
        self { @MainActor in WebviewHandlerImpl() }.singleton
    }
}

internal protocol WebviewHandler: Sendable {
    var isWebViewInitialized: Bool { get async }
    func reloadWebView() async
    func reinitializeWebView() async
    func awaitReady(timeout: Duration) async throws
    func createEthereumWallet(data: CreateEthereumWalletRequestData, timeout: Duration) async throws -> CreateEthereumWalletResponse
    func createSolanaWallet(data: CreateSolanaWalletRequestData, timeout: Duration) async throws -> CreateSolanaWalletResponse
    func createAdditionalWallet(data: ChainAgnosticCreateAdditionalWalletRequestData, timeout: Duration) async throws -> ChainAgnosticCreateAdditionalWalletResponse
    func connect(data: ChainAgnosticWalletConnectRequestData) async throws -> ChainAgnosticWalletConnectResponse
    func recover(data: ChainAgnosticWalletRecoverRequestData, timeout: Duration) async throws -> WalletRecoverResponse
    func rpc<T: Encodable>(data: WalletRpcRequestData<T>) async throws -> WalletRpcResponse
    func setPassword(data: WalletSetPasswordRequestData) async throws -> WalletSetPasswordResponse
    func signWithUserSigner(data: UserSignerSignRequestData) async throws -> UserSignerSignResponse
    func delegateActions(data: DelegateActionsRequestData) async throws -> DelegateActionsResponse
    func setMfaToken(data: MfaSetTokenRequestData) async throws -> MfaSetTokenResponse
    func clearMfa(data: ClearMfaRequestData) async throws -> ClearMfaResponse
}

private final class WebviewHandlerImpl: NSObject, WebviewHandler {
    private let iframeManager: PrivyIFrameWrapper = resolve(\PrivyContainer.privyIFrameWrapper)
    private let logger: Logger = resolve(\PrivyContainer.logger)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)
    private let breadcrumbEmitter: BreadcrumbEmitter = resolve(\PrivyContainer.breadcrumbEmitter)

    var isWebViewInitialized: Bool {
        get async { await iframeManager.isWebViewInitialized }
    }

    override init() {
        super.init()
    }

    // MARK: - Public API

    func reloadWebView() async {
        await iframeManager.reload()
    }

    func reinitializeWebView() async {
        await iframeManager.reinitialize()
    }

    func awaitReady(timeout: Duration = .seconds(15)) async throws {
        // attempt to ping ready with a 15 second timeout
        do {
            try await taskWithTimeout(timeout: timeout) {
                try await self.pingReadyUntilSuccessfulOrCancelled()
            }
        } catch {
            logger.verbose("pingReadyUntilSuccessfulOrCancelled error: \(error)")
            throw error
        }
    }

    func createEthereumWallet(data: CreateEthereumWalletRequestData, timeout: Duration = .seconds(60)) async throws -> CreateEthereumWalletResponse {
        let request = CreateEthereumWalletRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request, timeout: timeout)
    }

    func createSolanaWallet(data: CreateSolanaWalletRequestData, timeout: Duration = .seconds(60)) async throws -> CreateSolanaWalletResponse {
        let request = CreateSolanaWalletRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request, timeout: timeout)
    }

    func createAdditionalWallet(data: ChainAgnosticCreateAdditionalWalletRequestData, timeout: Duration = .seconds(60)) async throws -> ChainAgnosticCreateAdditionalWalletResponse {
        let request = ChainAgnosticCreateAdditionalWalletRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request, timeout: timeout)
    }

    func connect(data: ChainAgnosticWalletConnectRequestData) async throws -> ChainAgnosticWalletConnectResponse {
        let request = ChainAgnosticWalletConnectRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request, timeout: .seconds(60))
    }

    func recover(data: ChainAgnosticWalletRecoverRequestData, timeout: Duration = .seconds(60)) async throws -> WalletRecoverResponse {
        let request = ChainAgnosticWalletRecoverRequest(id: toUniqueId(), data: data)
        let response: WalletRecoverResponse = try await awaitReadyThenExecute(request: request, timeout: timeout)
        try await iframeManager.getLocalStorage()
        return response
    }

    func rpc<T: Encodable>(data: WalletRpcRequestData<T>) async throws -> WalletRpcResponse {
        let request = WalletRpcRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request, timeout: .seconds(60))
    }

    func setPassword(data: WalletSetPasswordRequestData) async throws -> WalletSetPasswordResponse {
        let request = WalletSetPasswordRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request)
    }

    func signWithUserSigner(data: UserSignerSignRequestData) async throws -> UserSignerSignResponse {
        let request = UserSignerSignRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request, timeout: .seconds(60))
    }

    func delegateActions(data: DelegateActionsRequestData) async throws -> DelegateActionsResponse {
        let request = DelegateActionsRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request, timeout: .seconds(60))
    }

    func setMfaToken(data: MfaSetTokenRequestData) async throws -> MfaSetTokenResponse {
        let request = MfaSetTokenRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request)
    }

    func clearMfa(data: ClearMfaRequestData) async throws -> ClearMfaResponse {
        let request = ClearMfaRequest(id: toUniqueId(), data: data)
        return try await awaitReadyThenExecute(request: request)
    }
}

// MARK: - Private Helper Methods

private extension WebviewHandlerImpl {
    func pingReadyUntilSuccessfulOrCancelled() async throws {
        let webViewState = WebViewState()

        // while web view is not ready, keep attempting ready ping
        while await !webViewState.isReady {
            // Since this method can time out, check if the task was cancelled
            if (Task.isCancelled) {
                logger.verbose("pingReady task was cancelled, propagating error up.")
                throw CancellationError()
            }

            do {
                _ = try await self.pingReady()
                logger.verbose("Webview is ready.")
                // if ping ready doesn't throw, webview is ready
                await webViewState.setReady(true)
                break
            } catch {
                // if ping ready throws, we retry in half of a second
                try await Task.sleep(for: .seconds(0.5))
            }
        }
    }

    func pingReadyUntilCancelledTask() -> Task<Void, Error> {
        let task = Task {
            // Loop indefinitely. The only ways out are by Task.sleep or Task.checkCancellation()
            // throwing a CancellationError, or if an unexpected unhandled error occurs.
            while true {
                // 1. Check for cancellation before doing any work
                try Task.checkCancellation()

                // Safe to silently fail because purpose is to keep pinging the webview while another
                // request is in progress. We don't actually care if it ready ping succeeds / fails
                _ = try? await self.pingReady()

                // 2. Suspend for 1 second. If the task is cancelled during this sleep,
                // Task.sleep will automatically throw a CancellationError, exiting the 'while true' loop.
                try await Task.sleep(for: .seconds(0.5))
            }
        }

        return task
    }

    func taskWithTimeout<T: Sendable>(
        timeout: Duration = .seconds(15),
        task: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await task()
            }

            group.addTask {
                // Convert Duration to nanoseconds here
                let timeoutInSeconds = timeout / .seconds(1)
                try await Task.sleep(nanoseconds: UInt64(timeoutInSeconds * 1_000_000_000))
                // Since this is within a withThrowingTaskGroup, throwing an error here
                // will automatically cancel the other child task. The main child task should
                // make cancellation is handled
                throw CancellationError()
            }

            let result = try await group.next()!

            // Important: if result didn't throw, that means main task successfully returned, so cancel sleep task!
            group.cancelAll()

            return result
        }
    }

    func pingReady(timeout: Duration = .milliseconds(150)) async throws -> IframeReadyResponse {
        // The ready probe can run while the webview is still loading and must use the same
        // timeout and cancellation path as every other iframe request.
        let request = IframeReadyRequest(id: toUniqueId())

        return try await performRequest(request: request, timeout: timeout)
    }

    func performRequest<T: PrivyIframeResponse>(request: any PrivyIframeRequest, timeout: Duration = .seconds(15)) async throws -> T {
        return try await iframeManager.sendRequest(request: request, timeout: timeout)
    }

    func toUniqueId() -> String {
        UUID().uuidString.lowercased()
    }

    func awaitReadyThenExecute<T: PrivyIframeResponse>(
        request: any PrivyIframeRequest,
        timeout: Duration = .seconds(60)
    ) async throws -> T {
        do {
            // first await ready to make sure webview is fully loaded
            try await awaitReady()
        } catch {
            breadcrumbEmitter.emit(.walletBridgeFailed(operation: request.event.rawValue, error: error))
            throw error
        }

        // start pinging ready every second so webview stays awake
        let pingReadyTask = pingReadyUntilCancelledTask()

        // important - cancel ping ready task once request is completed
        defer { pingReadyTask.cancel() }

        return try await ongoingMfaManager.withMfaHandling { mfaToken in
            // sync MFA token to iframe before performing request
            try await self.syncMfaTokenToIframe(mfaToken: mfaToken)
            return try await self.performRequest(request: request, timeout: timeout)
        }
    }

    func syncMfaTokenToIframe(mfaToken: String?) async throws {
        let authManager: AuthManager = resolve(\PrivyContainer.authManager)

        let auth = try authManager.ensureAuthenticated()

        let tokenToUse: String
        if let mfaToken {
            tokenToUse = mfaToken
        } else if !auth.user.mfaMethods.isEmpty {
            // User is MFA enrolled but has no token - use stub to trigger webview MFA prompt
            tokenToUse = "stub-mfa-token"
        } else {
            // No MFA token and user is not MFA enrolled - nothing to sync
            return
        }

        let data = MfaSetTokenRequestData(accessToken: auth.authToken, mfaToken: tokenToUse)
        let request = MfaSetTokenRequest(id: toUniqueId(), data: data)

        // Use performRequest directly to avoid recursion (setMfaToken calls awaitReadyThenExecute)
        _ = try await performRequest(request: request) as MfaSetTokenResponse
    }
}

// Important - this must be an actor to ensure atomic operations
fileprivate actor WebViewState {
    private(set) var isReady = false

    func setReady(_ ready: Bool) {
        self.isReady = ready
    }
}
