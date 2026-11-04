internal import FactoryKit
@preconcurrency import Combine

// A class that manages WebView loaded state
// WebView is considered loaded after navigation completes successfully
internal final class WebViewLoadedStateHandler: Sendable {
    private let logger: Logger = resolve(\PrivyContainer.logger)

    // Value subject that holds the value of WebView loaded state
    private let isLoadedSubject = CurrentValueSubject<Bool, Never>(true)

    internal func setLoading() {
        logger.verbose("Setting webview load state to loading")
        isLoadedSubject.send(false)
    }

    internal func setLoaded() {
        logger.verbose("Setting webview load state to loaded")
        isLoadedSubject.send(true)
    }

    internal func awaitLoaded() async {
        // If loaded is already true, immediately return
        if isLoaded() {
            return
        }

        logger.verbose("Webview isn't loaded yet, waiting...")

        // If not, wait until isLoadedSubject fires true, then return
        for await isLoaded in isLoadedSubject.values {
            if isLoaded {
                logger.verbose("Webview had loaded, continuing.")
                return
            }
        }
    }

    internal func isLoaded() -> Bool {
        return isLoadedSubject.value
    }
}
