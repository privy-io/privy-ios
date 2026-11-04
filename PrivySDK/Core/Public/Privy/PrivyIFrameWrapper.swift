import Foundation
import WebKit
internal import FactoryKit
@preconcurrency import Combine

extension PrivyContainer {
    internal var privyIFrameWrapper: Factory<PrivyIFrameWrapper> {
        self { @MainActor in PrivyIFrameManagerImpl() }.singleton
    }
}

// Everything related to webview should be on Main thread
@MainActor
internal protocol PrivyIFrameWrapper: Sendable {
    var isWebViewInitialized: Bool { get }
    func reload() async
    func reinitialize() async
    func getLocalStorage() async throws
    func sendRequest<T: PrivyIframeResponse>(request: any PrivyIframeRequest, timeout: Duration) async throws -> T
}

@MainActor
private final class PrivyIFrameManagerImpl: NSObject, PrivyIFrameWrapper {
    @Injected(\PrivyContainer.config) private var config: PrivyConfig
    @Injected(\PrivyContainer.logger) private var logger: Logger
    private let caidRepository: ClientAnalyticsIdRepository = resolve(\PrivyContainer.caidRepository)

    // Access this through getWebView() so callers cannot observe an uninitialized webview.
    private var webview: WKWebView?

    private let loadedStateHandler = WebViewLoadedStateHandler()
    private let completionHandlerStore = CompletionHandlerStore()

    var isWebViewInitialized: Bool { webview != nil }

    override init() {
        super.init()
    }

    // MARK: - PrivyIFrameManager Protocol Implementation

    func reload() {
        reloadWebView()
    }

    func reinitialize() {
        let _ = initializeWebViewAndLoadIFrame()
    }

    func getLocalStorage() async throws {
        let javascriptToFetchLocalStorage = "JSON.stringify(localStorage)"
        _ = try? await evaluateJavaScript(javascriptToFetchLocalStorage)
    }

    func sendRequest<T>(request: any PrivyIframeRequest, timeout: Duration) async throws -> T where T: PrivyIframeResponse {
        return try await self.performRequestAndHandleTimeout(request: request, timeout: timeout)
    }
}

// MARK: Webview loading / intialization

extension PrivyIFrameManagerImpl {
    // Return the existing webview or create a new one. No race condition concern here since
    // this whole class runs on MainActor, so calls to this method will execute sequentially
    private func getWebView() -> WKWebView {
        if let webView = self.webview {
            return webView
        } else {
            return initializeWebViewAndLoadIFrame()
        }
    }

    private func initializeWebViewAndLoadIFrame() -> WKWebView {
        // Clear out any existing webview
        self.webview = nil

        // Set loading state before starting webview creation / iFrame loading
        loadedStateHandler.setLoading()

        let scriptSource = "window.PRIVY_NATIVE_IOS = true;"
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)

        let controller = WKUserContentController()
        controller.addUserScript(script)
        controller.add(self, name: "iOSProxy")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let newWebview = WKWebView(frame: .zero, configuration: configuration)
        newWebview.navigationDelegate = self
        #if DEBUG
            if #available(iOS 16.4, *) {
                newWebview.isInspectable = true
            }
        #endif

        self.webview = newWebview

        // Safe to load asynchronously: loadedStateHandler is already in .loading state,
        // so all webview requests will await completion via awaitLoaded() before executing.
        Task {
            try? await loadIFrameUrl(config: config)
        }

        return newWebview
    }

    private func loadIFrameUrl(config: PrivyConfig) async throws {
        loadedStateHandler.setLoading()

        let caid = await caidRepository.loadClientId()
        let urlString = config.getEmbeddedWalletURL(caid: caid)

        guard let url = URL(string: urlString) else {
            throw PrivyError(.initializationFailed)
        }

        logger.verbose("Loading web view")
        getWebView().load(URLRequest(url: url))
    }

    private func reloadWebView() {
        // Set loading state before starting reload
        loadedStateHandler.setLoading()

        // Asynchronously trigger webpage reload
        getWebView().reload()
    }
}

// MARK: Request execution

extension PrivyIFrameManagerImpl {
    // Helper function that converts dispatching a Privy request into an async flow
    // It dispatches request to webview, and awaits the response with a throwing continuation
    // The continuation will throw if the request times out or the request itself fails
    private func performRequestAndHandleTimeout<T: PrivyIframeResponse>(request: any PrivyIframeRequest, timeout: Duration = .seconds(15)) async throws -> T {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            Task {
                let manager = ContinuationManager<T>(eventType: request.event, logger: logger)

                // Create dispatch item for timeout
                let timeoutWorkItem = DispatchWorkItem {
                    Task {
                        self.logger.verbose("\(request.event.rawValue) timed out")
                        manager.handleTimeout(continuation: continuation)
                    }
                }

                manager.storeTimeoutItem(item: timeoutWorkItem)

                // Add completion handler to the completionHandlerStore map.
                let completionHandler: @Sendable (String) -> Void = { [logger] msg in
                    guard !Task.isCancelled else {
                        logger.verboseInternal("sendRequest: Completion handler invoked after cancellation. Ignoring.")
                        return
                    }

                    Task {
                        await manager.handleCompletion(msg: msg, continuation: continuation)
                    }
                }

                let holder = CompletionHandlerHolder(completion: completionHandler)
                await completionHandlerStore.set(holder, forId: request.id)

                // Send request to webview
                logger.verbose("Dispatching \(request.event.rawValue) to webview")

                do {
                    try await dispatchPrivyRequestToWebView(request: request)

                    // Queue up timeout dispatch item
                    let timeoutInterval = timeout / .seconds(1)
                    DispatchQueue.main.asyncAfter(deadline: .now() + timeoutInterval, execute: timeoutWorkItem)
                } catch {
                    // Error evaluating javascript. Cancel timeout
                    timeoutWorkItem.cancel()

                    logger.logInternal(
                        level: .verbose,
                        message: "JavaScript evaluation error: \(error.localizedDescription)"
                    )

                    // Remove completion handler
                    await completionHandlerStore.remove(id: request.id)

                    // Invoke continuation with error
                    manager.handleJavaScriptEvaluationError(continuation: continuation)
                }
            }
        }
    }

    // Helper function that dispatches request to webview
    private func dispatchPrivyRequestToWebView(request: any PrivyIframeRequest) async throws {
        guard let msg = request.stringData else { return }

        // print request for everything except iframe ready
        if !msg.contains("privy:iframe:ready") {
            logger.logInternal(level: .verbose, message: """


                >>>>>>>>>>>> Request sent to webview >>>>>>>>>>>>
                \(msg)
                >>>>>>>>>>>> End request sent to webview >>>>>>>>>>>>

                """
            )
        }

        try await evaluateJavaScript("window.dispatchEvent(new MessageEvent('message', { data: \(msg)}));")
    }

    private func evaluateJavaScript(_ script: String) async throws {
        // Wait for webview to be loaded before evaluating JavaScript
        await loadedStateHandler.awaitLoaded()

        try await getWebView().evaluateJavaScript(script)
    }
}

// MARK: - WKNavigationDelegate (listens for webview loaded state and handles webview process termination)

extension PrivyIFrameManagerImpl: WKNavigationDelegate {
    internal func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        logger.verbose("Started loading webview")
    }

    internal func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.verbose("Finished loading webview")

        self.loadedStateHandler.setLoaded()
    }

    internal func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.verbose("Failed to load webview with error: \(error.localizedDescription)")

        // This should never actually happen since we know we are loading a valid webpage, but notify load state handler
        // just in case to unblock any caller who is awaiting loaded
        self.loadedStateHandler.setLoaded()
    }

    internal func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.verbose("Webview failed navigation: \(error.localizedDescription)")

        // This should never actually happen since we know we are loading a valid webpage, but notify load state handler
        // just in case to unblock any caller who is awaiting loaded
        self.loadedStateHandler.setLoaded()
    }

    internal func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        logger.error("WebView process terminated by system. Attempting to recover by recreating WebView", error: nil)

        Task {
            // Clear all pending completion handlers
            await completionHandlerStore.clearAllWithError()

            // Recreate the webview after process termination
            self.initializeWebViewAndLoadIFrame()
        }
    }
}

// MARK: - WKScriptMessageHandler (message response handling)

extension PrivyIFrameManagerImpl: WKScriptMessageHandler {
    internal func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Handle the message internally
        handleMessage(message)
    }

    private func handleMessage(_ message: WKScriptMessage) {
        // print response for all requests except iFrame ready
        if !((message.body as? String)?.contains("privy:iframe:ready") == true) {
            logger.logInternal(level: .verbose, message: """


            <<<<<<<<<<<< Response received from webview <<<<<<<<<<<<
            \(message.body)
            <<<<<<<<<<<< End received from webview <<<<<<<<<<<<

            """)
        }

        guard let msg = message.body as? String else {
            logger.logInternal(level: .verbose, message: "error casting iframe message body to string")
            logger.logInternal(level: .verbose, message: "message.body: \(message.body)")
            return
        }

        // Extract ID and handle response
        guard let id = getId(str: msg) else { return }
        handleResponse(id: id, message: msg)
    }

    private func handleResponse(id: String, message: String) {
        Task {
            // Look up the completion handler for a specified request ID, and invoke the continuation
            if let completionHandler = await completionHandlerStore.getAndRemove(forId: id) {
                logger.logInternal(level: .verbose, message: "Triggering completion handler")
                completionHandler.completion(message)
            } else {
                logger.logInternal(level: .verbose, message: "No completion handler found for message.")
            }
        }
    }

    private func getId(str: String) -> String? {
        let regex = /.*"id":"(?<uniqueId>[a-z0-9-]+)".*/
        guard let result = str.wholeMatch(of: regex) else { return nil }
        return result.output.uniqueId.lowercased()
    }
}
