import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var logger: Factory<Logger> {
        self { ConsoleLogger() }.singleton
    }
}

private final class ConsoleLogger: Logger {
    /// The log level set by the app developer
    nonisolated(unsafe) var appLogLevel: PrivyLogLevel = .none

    /// The custom logger set by the developer
    nonisolated(unsafe) var logMessage: ((PrivyLogLevel, String) -> Void)? = nil

    // The application id set during initialization
    nonisolated(unsafe) var appId: String? = nil

    func setInfo(appInfo: PrivyConfig) {
        appLogLevel = appInfo.loggingConfig?.logLevel ?? .none
        logMessage = appInfo.loggingConfig?.logMessage
        appId = appInfo.appId
    }

    func log(level: PrivyLogLevel, message: String) {
        guard level <= appLogLevel else {
            // Logs with a level higher than the application's set log level are not printed.
            return
        }

        printLog(level: level, message: message)
    }

    func logInternal(level: PrivyLogLevel, message: String) {
        guard level <= appLogLevel else {
            // Logs with a level higher than the application's set log level are not printed.
            return
        }

        guard let appId = appId, appId.isInternalAppId() else {
            // Diagnostic logs are enabled only for approved demo applications.
            return
        }

        printLog(level: level, message: "[Internal] \(message)")
    }

    func printLog(level: PrivyLogLevel, message: String) {
        if let customLogger = logMessage {
            // if dev passed in custom logger, send log to them
            customLogger(level, message)
        } else {
            // else, print log to console
            let timestamp = Date().formatted(Date.ISO8601FormatStyle())
            let levelTag = String(describing: level).uppercased()
            print("PRIVY [\(levelTag)]: \(timestamp) \(message)")
        }
    }
}
