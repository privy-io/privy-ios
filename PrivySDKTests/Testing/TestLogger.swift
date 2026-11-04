@testable import PrivySDK

/// In-memory `Logger` test double. Records calls instead of printing them, so tests can assert on
/// logging behavior.
internal final class TestLogger: Logger, @unchecked Sendable {
    internal struct LoggedMessage: Equatable {
        internal let level: PrivyLogLevel
        internal let message: String
    }

    internal private(set) var messages: [LoggedMessage] = []
    internal private(set) var internalMessages: [LoggedMessage] = []

    internal func log(level: PrivyLogLevel, message: String) {
        messages.append(LoggedMessage(level: level, message: message))
    }

    internal func logInternal(level: PrivyLogLevel, message: String) {
        internalMessages.append(LoggedMessage(level: level, message: message))
    }

    internal func setInfo(appInfo: PrivyConfig) {}
}
