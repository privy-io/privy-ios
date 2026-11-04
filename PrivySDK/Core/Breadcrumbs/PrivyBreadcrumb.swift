import Foundation

/// A lightweight diagnostic event describing a step in a Privy SDK flow (e.g. login started,
/// session restore failed). Register a ``PrivyBreadcrumbHandler`` via ``PrivyConfig`` to receive
/// these and route them to your own analytics or observability tooling.
public struct PrivyBreadcrumb: Sendable {
    /// Dotted event name, e.g. "auth.login.started".
    public let event: String

    /// The time at which the event occurred.
    public let timestamp: Date

    /// Additional context for the event. Values are strings only; must not contain PII.
    public let data: [String: String]

    internal init(event: String, timestamp: Date, data: [String: String]) {
        self.event = event
        self.timestamp = timestamp
        self.data = data
    }
}

extension Error {
    /// A stable, non-sensitive code for use in breadcrumb payloads.
    /// For `PrivyError`, returns the error code hierarchy (no associated values).
    /// For all other error types, returns only the Swift type name.
    internal var breadcrumbCode: String {
        if let privyError = self as? PrivyError {
            return privyError.breadcrumbCode
        }
        return String(describing: type(of: self))
    }
}
