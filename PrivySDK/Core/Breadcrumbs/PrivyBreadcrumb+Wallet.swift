import Foundation

/// Wallet critical path breadcrumb events: `wallet.create.started/completed/failed` and
/// `wallet.import.started/completed/failed`.
extension PrivyBreadcrumb {
    internal static func walletCreateStarted(chainType: ChainType) -> PrivyBreadcrumb {
        PrivyBreadcrumb(event: "wallet.create.started", timestamp: Date(), data: ["chain-type": chainType.rawValue])
    }

    internal static func walletCreateCompleted(chainType: ChainType) -> PrivyBreadcrumb {
        PrivyBreadcrumb(event: "wallet.create.completed", timestamp: Date(), data: ["chain-type": chainType.rawValue])
    }

    internal static func walletCreateFailed(chainType: ChainType, error: any Error) -> PrivyBreadcrumb {
        PrivyBreadcrumb(
            event: "wallet.create.failed",
            timestamp: Date(),
            data: ["chain-type": chainType.rawValue, "error": error.breadcrumbCode]
        )
    }

    internal static func walletImportStarted(chainType: WalletImportSupportedChainType) -> PrivyBreadcrumb {
        PrivyBreadcrumb(event: "wallet.import.started", timestamp: Date(), data: ["chain-type": chainType.rawValue])
    }

    internal static func walletImportCompleted(chainType: WalletImportSupportedChainType) -> PrivyBreadcrumb {
        PrivyBreadcrumb(event: "wallet.import.completed", timestamp: Date(), data: ["chain-type": chainType.rawValue])
    }

    internal static func walletImportFailed(chainType: WalletImportSupportedChainType, error: any Error) -> PrivyBreadcrumb {
        PrivyBreadcrumb(
            event: "wallet.import.failed",
            timestamp: Date(),
            data: ["chain-type": chainType.rawValue, "error": error is CancellationError ? "cancelled" : error.breadcrumbCode]
        )
    }

    internal static func walletMigrationStarted() -> PrivyBreadcrumb {
        PrivyBreadcrumb(event: "wallet.migration.started", timestamp: Date(), data: [:])
    }

    internal static func walletMigrationCompleted() -> PrivyBreadcrumb {
        PrivyBreadcrumb(event: "wallet.migration.completed", timestamp: Date(), data: [:])
    }

    internal static func walletMigrationFailed(error: any Error) -> PrivyBreadcrumb {
        PrivyBreadcrumb(event: "wallet.migration.failed", timestamp: Date(), data: ["error": error.breadcrumbCode])
    }

    /// The webview/iframe bridge failed to complete a wallet operation (e.g. the bridge timed out
    /// or errored), as opposed to the operation itself being rejected by the server.
    internal static func walletBridgeFailed(operation: String, error: any Error) -> PrivyBreadcrumb {
        PrivyBreadcrumb(
            event: "wallet.bridge.failed",
            timestamp: Date(),
            data: ["operation": operation, "error": error.breadcrumbCode]
        )
    }
}
