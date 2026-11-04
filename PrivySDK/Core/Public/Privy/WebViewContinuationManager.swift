import Foundation

internal final class ContinuationManager<T: PrivyIframeResponse>: @unchecked Sendable {
    private let eventType: PrivyEventType
    private let logger: Logger
    private var wasContinuationInvoked = false
    private var timeoutItem: DispatchWorkItem? = nil

    internal init(eventType: PrivyEventType, logger: Logger) {
        self.eventType = eventType
        self.logger = logger
    }

    internal func storeTimeoutItem(item: DispatchWorkItem) {
        self.timeoutItem = item
    }

    internal func handleCompletion(msg: String, continuation: CheckedContinuation<T, Error>) async {
        logger.verboseInternal("\(eventType.rawValue) webview request completed.")

        guard !Task.isCancelled else {
            logger.verboseInternal("Task was cancelled. Returning.")
            return
        }

        logger.verboseInternal("Cancelling timeout check.")
        self.timeoutItem?.cancel()
        self.timeoutItem = nil

        continueIfValid {
            if msg.contains("error") {
                do {
                    let response = try IframeErrorResponse.init(str: msg)
                    let iframeError = PrivyError(
                        .embeddedWalletFailure(
                            reason: .iframeError(type: response.error.type, message: response.error.message)
                        )
                    )
                    logger.verboseInternal("Invoking continuation with error: \(iframeError)")
                    continuation.resume(throwing: iframeError)
                } catch {
                    logger.verboseInternal("Invoking continuation with error: \(error)")
                    continuation.resume(throwing: error)
                }
            } else {
                do {
                    let response = try T.init(str: msg)
                    logger.verboseInternal("Invoking continuation with response: \(response)")
                    continuation.resume(returning: response)
                } catch {
                    logger.verboseInternal("Error parsing response msg. Invoking continuation with error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    internal func handleJavaScriptEvaluationError(continuation: CheckedContinuation<T, Error>) {
        continueIfValid {
            continuation.resume(throwing: PrivyError(.embeddedWalletFailure(reason: .secureContextFailed)))
        }
    }

    internal func handleTimeout(continuation: CheckedContinuation<T, Error>) {
        continueIfValid {
            self.timeoutItem = nil
            continuation.resume(throwing: PrivyError(.embeddedWalletFailure(reason: .timeout)))
        }
    }

    private func continueIfValid(action: () -> Void) {
        if !wasContinuationInvoked {
            wasContinuationInvoked = true
            action()
        } else {
            logger.verboseInternal("Continuation already invoked. Not invoking again.")
        }
    }
}
