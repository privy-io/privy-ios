internal import FactoryKit
import Foundation
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

extension PrivyContainer {
    internal var webViewAppLifecycleManager: Factory<WebViewAppLifecycleManager> {
        self { @MainActor in WebViewAppLifecycleManager() }.singleton
    }
}

@MainActor
internal class WebViewAppLifecycleManager: NSObject, Sendable {
    @Injected(\PrivyContainer.logger) private var logger: Logger
    @Injected(\PrivyContainer.webViewHandler) private var webViewHandler: WebviewHandler
    private let internalAuthStateManager: InternalAuthStateManager = resolve(\PrivyContainer.internalAuthStateManager)
    private let webViewWalletConnector: WebViewWalletConnector = resolve(\PrivyContainer.webViewWalletConnector)
    private var shouldPingReadyOnForeground = false

    fileprivate override init() {
        super.init()

        // Initialize app event listeners
        self.initializeAppEventListeners()

        // Initialize authenticate state listener
        self.subscribeToAuthUpdates()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func subscribeToAuthUpdates() {
        Task {
            // Store current state before subscribing to auth state stream
            var priorState = internalAuthStateManager.state

            for await authState in internalAuthStateManager.stateStream {
                // Check if the user just authenticated from an unauthenticated state
                if case let .authenticated(authSession) = authState, !priorState.isConfirmedAuthenticated {
                    // Okay to fail since this is best attempt to preemptively load webview
                    await onNewlyAuthenticatedUser(authSession: authSession)
                }

                // Update "prior auth state" to latest
                priorState = authState
            }
        }
    }

    private func onNewlyAuthenticatedUser(authSession: InternalAuthSession) async {
        // Only load webview if user has on-device (non-TEE) wallets that need it
        guard let wallet = try? authSession.user.linkedAccounts.getPrimaryWalletForEntropyInfo(),
              !wallet.isTEEWallet
        else {
            logger.verboseInternal("Skipping proactive webview load — user has no on-device wallets")
            return
        }

        // proactively (re)load webview for a clean state, this has helped with webview hanging issues
        logger.infoInternal("Proactively reloading webview for authenticated user with on-device wallets")
        await webViewWalletConnector.reloadWebView()

        logger.debug("Proactively attempting wallet connect since user is authenticated.")

        // Since we are doing this best effort, silently fail if connecting throws
        do {
            try await webViewWalletConnector.ensurePrimaryEmbeddedWalletConnected()
        } catch {
            logger.error("Proactively attempting wallet connect FAILED.", error: error)
        }
    }

    private func initializeAppEventListeners() {
        #if os(iOS)
            NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        #elseif os(macOS)
            NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: NSApplication.didResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: NSApplication.didBecomeActiveNotification, object: nil)
        #endif
    }

    @objc private func appDidEnterBackground(_ notification: Notification) {
        logger.logInternal(level: .verbose, message: "App did enter background.")

        // Set a boolean field indicating app was backgrounded, so that on foreground, we resume webview flows if needed
        self.shouldPingReadyOnForeground = true
    }

    @objc private func appWillEnterForeground(_ notification: Notification) {
        if self.shouldPingReadyOnForeground {
            logger.logInternal(level: .verbose, message: "App is entering foreground.")
            self.shouldPingReadyOnForeground = false
            self.ensureJavascriptContextStillValidIfNeeded()
        }
    }

    private func ensureJavascriptContextStillValidIfNeeded() {
        Task {
            guard await webViewHandler.isWebViewInitialized else {
                logger.verboseInternal("Skipping webview health check on foreground — webview not initialized")
                return
            }

            do {
                logger.logInternal(level: .verbose, message: "Checking if secure context is still valid")
                // first try ready ping w/ 500 ms timeout to see if javascript context is still active
                let _ = try await webViewHandler.awaitReady(timeout: .milliseconds(500))

                logger.logInternal(level: .verbose, message: "Secure context is still valid!")
            } catch {
                logger.logInternal(level: .verbose, message: "Secure context is invalid. Attempting to recreate.")
                // If JS context is invalid, we want to reinitialize the webview (not just reload the iFrame)
                await webViewHandler.reinitializeWebView()
            }
        }
    }
}
