import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var webViewWalletConnector: Factory<WebViewWalletConnector> {
        self { WebViewWalletConnectorImpl() }.unique
    }
}

/// Protocol used for connecting to an embedded wallet, giving the option to use different strategies based on the type of wallet.
/// This protocol is also in charge of embedded wallet recovery if applicable.
internal protocol WebViewWalletConnector: Sendable {
    /// Ensures the user's primary embedded wallet is ready for use, or otherwise attempts to connect and recover before resuming.
    /// This operation is idempotent, and should be called before every operation that needs it.
    /// - Throws: If wallet connection fails.
    func ensurePrimaryEmbeddedWalletConnected() async throws
    /// Attempts to recover the wallet if the error received is an iframe error about `wallet_not_on_device`.
    /// - Returns: returns without throwing only if the error was recovery *and* recovery was successful.
    /// - Throws: forwards any non-recovery-needed errors or errors thrown by the attempt to recover.
    func handleRecoveryIfNeededOrThrow(error: Error) async throws

    /// Connects a specific wallet account without updating the primary wallet state.
    ///
    /// - Parameter account: The wallet account to connect.
    ///
    /// - Throws: If wallet connection fails.
    func connectWallet(for account: any EmbeddedWalletAccount) async throws

    func reloadWebView() async
}

/// A mechanism for connecting to a user's embedded wallets using the webview, via the `connect` command,
/// also calling the `recover` command if necessary.
private final actor WebViewWalletConnectorImpl: WebViewWalletConnector {
    private let logger: Logger = resolve(\PrivyContainer.logger)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let embeddedWalletStateManager: EmbeddedWalletStateManager = resolve(\PrivyContainer.embeddedWalletStateManager)
    private let handler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)

    internal func ensurePrimaryEmbeddedWalletConnected() async throws {
        let _ = try authManager.ensureAuthenticated()

        if case .connected = await embeddedWalletStateManager.state {
            // Wallet is already connected
            return
        }

        let auth = try await authManager.refreshSessionIfNeeded()
        let primaryWallet = try auth.user.linkedAccounts.getPrimaryWalletForEntropyInfo()
        try await connectWallet(for: primaryWallet, recoverIfRequired: true)
        await embeddedWalletStateManager.update(newState: .connected)
    }

    internal func connectWallet(for account: any EmbeddedWalletAccount) async throws {
        try await connectWallet(for: account, recoverIfRequired: true)
    }

    func reloadWebView() async {
        // Clear connected state before reloading
        await embeddedWalletStateManager.update(newState: .disconnected)

        await handler.reloadWebView()
    }

    private func connectWallet(for account: any EmbeddedWalletAccount, recoverIfRequired: Bool) async throws {
        let auth = try await authManager.refreshSessionIfNeeded()

        do {
            let data = ChainAgnosticWalletConnectRequestData(wallet: account, accessToken: auth.authToken)
            logger.verbose("Attempting to connect wallet \(account.address).")
            _ = try await handler.connect(data: data)
            logger.verbose("Wallet \(account.address) connected!")
        } catch {
            try await handleRecoveryIfNeededOrThrow(
                error: error,
                recoverIfRequired: recoverIfRequired,
                accessToken: auth.authToken,
                account: account
            )
        }
    }

    func handleRecoveryIfNeededOrThrow(error: any Error) async throws {
        let auth = try await authManager.refreshSessionIfNeeded()
        let primaryWallet = try auth.user.linkedAccounts.getPrimaryWalletForEntropyInfo()

        try await handleRecoveryIfNeededOrThrow(
            error: error,
            recoverIfRequired: true,
            accessToken: auth.authToken,
            account: primaryWallet
        )
        // Recovery was successful, update state for the primary wallet
        await embeddedWalletStateManager.update(newState: .connected)
    }

    private func handleRecoveryIfNeededOrThrow(
        error: Error,
        recoverIfRequired: Bool,
        accessToken: String,
        account: any EmbeddedWalletAccount
    ) async throws {
        if let privyError = error as? PrivyError,
           case .embeddedWalletFailure(reason: .iframeError(type: "wallet_not_on_device", message: _)) = privyError.errorCode,
           recoverIfRequired {
            logger.verbose("Wallet recovery required. Attempting recovery.")

            // iframe (or the webview) is missing the device share for the embedded wallet - so we need to recover it
            try await recoverWallet(
                accessToken: accessToken,
                account: account,
                retryOnTimeout: true
            )
        } else {
            logger.error("Error connecting wallet.", error: error)
            // for all other errors, or if recovery is not required, propagate back up
            throw error
        }
    }

    func recoverWallet(
        accessToken: String,
        account: any EmbeddedWalletAccount,
        retryOnTimeout: Bool
    ) async throws {
        do {
            // Reload the webview before recovery. A stale webview can stop delivering recovery
            // responses, leaving the request pending until timeout.
            await reloadWebView()

            // attempt to recover wallet
            _ = try await handler.recover(
                data: ChainAgnosticWalletRecoverRequestData(
                    accessToken: accessToken,
                    entropyId: account.entropyId,
                    entropyIdVerifier: account.entropyIdVerifier
                ),
                timeout: .seconds(30)
            )

            logger.verbose("Wallet recovery successful. Reattemping wallet connect.")

            // if successful, try connecting wallet again
            return try await connectWallet(for: account, recoverIfRequired: false)
        } catch {
            if let privyError = error as? PrivyError, privyError.isWalletTimeoutError, retryOnTimeout {
                logger.verboseInternal("Couldn't recover wallet due to timeout. Reloading webview, then trying one more time.")

                // potentially refresh webview again
                await reloadWebView()

                logger.verboseInternal("Couldn't recover wallet. Reloaded webview. Trying connecting again.")

                // first recovery failed, try one more time since webview is reloaded
                return try await recoverWallet(
                    accessToken: accessToken,
                    account: account,
                    retryOnTimeout: false // if recover fails again, don't try again
                )
            }

            logger.error("Error recovering wallet,", error: error)
            // Propagate recovery error back up
            throw error
        }
    }
}
