import Foundation
internal import FactoryKit

/// Repository responsible for fetching the app configuration from the Privy API
internal protocol AppConfigRepository: Sendable {
    /// Loads the app configuration from the API
    /// - Returns: The app configuration
    /// - Throws: An error if loading fails
    func loadAppConfig() async throws -> AppConfig
}

extension PrivyContainer {
    internal var appConfigRepository: Factory<AppConfigRepository> {
        self { AppConfigRepositoryImpl() }.shared
    }
}

private actor AppConfigRepositoryImpl: AppConfigRepository {
    private let networkService: NetworkService = resolve(\PrivyContainer.networkService)
    private let config: PrivyConfig = resolve(\PrivyContainer.config)

    private var cachedAppConfig: AppConfig?

    fileprivate init() {
        // Best effort fetch so the cache is populated during app init, ready for callers
        Task { [weak self] in
            guard let self else { return }
            let _ = try? await self.loadAppConfig()
        }
    }

    internal func loadAppConfig() async throws -> AppConfig {
        if let cachedAppConfig {
            return cachedAppConfig
        }

        let request = try await networkService.makeRequest(path: "/api/v1/apps/\(config.appId)", token: nil, httpMethod: "GET")

        let appConfig: AppConfig = try await request.execute()

        self.cachedAppConfig = appConfig

        return appConfig
    }
}
