import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var caidRepository: Factory<ClientAnalyticsIdRepository> {
        self { ClientAnalyticsIdRepositoryImpl() }.singleton
    }
}

private actor ClientAnalyticsIdRepositoryImpl: ClientAnalyticsIdRepository {
    private var clientIdCache: String?

    private enum Constants {
        // Note: Do not change these or it will break backwards compatibility
        static let analyticsClientIdKey = "privyAnalyticsClientId"
    }

    fileprivate init() {}

    internal func loadClientId() async -> String {
        if let clientIdCache {
            return clientIdCache
        }

        if let storedClientId = UserDefaults.standard.string(forKey: Constants.analyticsClientIdKey) {
            clientIdCache = storedClientId
            return storedClientId
        }

        let generatedClientId = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generatedClientId, forKey: Constants.analyticsClientIdKey)
        clientIdCache = generatedClientId
        return generatedClientId
    }

    internal func resetClientId() async {
        UserDefaults.standard.removeObject(forKey: Constants.analyticsClientIdKey)
        clientIdCache = nil
    }
}
