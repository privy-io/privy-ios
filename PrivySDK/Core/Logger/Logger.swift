import Foundation

internal protocol Logger: Sendable {
    /// Log a message at the given level
    func log(level: PrivyLogLevel, message: String)

    /// Log a diagnostic message only for approved demo applications.
    func logInternal(level: PrivyLogLevel, message: String)

    func setInfo(appInfo: PrivyConfig)
}

internal extension Logger {
    func verbose(_ message: String) {
        log(level: .verbose, message: message)
    }

    func debug(_ message: String) {
        log(level: .debug, message: message)
    }

    func info(_ message: String) {
        log(level: .info, message: message)
    }

    func warning(_ message: String) {
        log(level: .warning, message: message)
    }

    func error(_ message: String, error: Error?) {
        guard let error = error else {
            return log(level: .error, message: message)
        }
        return log(level: .error, message: "\(message) [\(error.localizedDescription)]")
    }

    func verboseInternal(_ message: String) {
        logInternal(level: .verbose, message: message)
    }

    func debugInternal(_ message: String) {
        logInternal(level: .debug, message: message)
    }

    func infoInternal(_ message: String) {
        logInternal(level: .info, message: message)
    }

    func warningInternal(_ message: String) {
        logInternal(level: .warning, message: message)
    }

    func errorInternal(_ message: String, error: Error?) {
        guard let error = error else {
            return logInternal(level: .error, message: message)
        }
        return logInternal(level: .error, message: "\(message) [\(error)]")
    }
}
