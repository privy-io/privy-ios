import Foundation
@testable import PrivySDK

/// In-memory `AppConfigRepository` test double, defaulting to user-controlled server wallets.
internal final class TestAppConfigRepository: AppConfigRepository, @unchecked Sendable {
    internal var loadAppConfigResult: Result<AppConfig, Error> = .success(
        AppConfig(embeddedWalletConfig: EmbeddedWalletConfig(mode: .userControlledServerWalletsOnly))
    )

    internal func loadAppConfig() async throws -> AppConfig {
        try loadAppConfigResult.get()
    }
}
