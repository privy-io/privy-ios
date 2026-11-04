import Foundation

public enum PrivyLogLevel: Comparable, Sendable {
    case none
    /// Errors (excepted or otherwise) that are thrown during flows driven by the SDK, be it by internal methods or external dependencies called directly.
    case error
    /// Warnings on unexpected states that do not by themselves constitute an error, but may be indicative of their possibility or offer related information.
    case warning
    /// Logs about the steps the SDK is going through to implement certain functionality, displaying important info about the progress and intermediary states
    case info
    /// Useful in debugging by showing a level of detail that leans on the excess of detail, logging intermediary values and steps in the process
    case debug
    /// Details on the instructions and calls being made by the SDK in order to fulfill each request.
    case verbose
}
