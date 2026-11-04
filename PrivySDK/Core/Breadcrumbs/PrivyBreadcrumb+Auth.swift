import Foundation

/// Session restore breadcrumb events: `auth.session_restore.started/completed/failed`.
extension PrivyBreadcrumb {
    internal static func sessionRestoreStarted(loginMethod: LoginMethod) -> PrivyBreadcrumb {
        PrivyBreadcrumb(
            event: "auth.session_restore.started",
            timestamp: Date(),
            data: ["login-method": String(describing: loginMethod)]
        )
    }

    internal static func sessionRestoreCompleted(loginMethod: LoginMethod) -> PrivyBreadcrumb {
        PrivyBreadcrumb(
            event: "auth.session_restore.completed",
            timestamp: Date(),
            data: ["login-method": String(describing: loginMethod)]
        )
    }

    internal static func sessionRestoreFailed(loginMethod: LoginMethod, error: any Error) -> PrivyBreadcrumb {
        PrivyBreadcrumb(
            event: "auth.session_restore.failed",
            timestamp: Date(),
            data: ["login-method": String(describing: loginMethod), "error": error.breadcrumbCode]
        )
    }
}
