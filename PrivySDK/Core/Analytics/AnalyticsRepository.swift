import Foundation
internal import FactoryKit

internal protocol AnalyticsRepository: Sendable {
    func logEvent(_ analyticsEvent: AnalyticsEvent) async throws
}

extension PrivyContainer {
    internal var analyticsRepository: Factory<AnalyticsRepository> {
        self { AnalyticsRepositoryImpl() }.shared
    }
}

private final class AnalyticsRepositoryImpl: AnalyticsRepository {
    private let networkService: NetworkService = resolve(\PrivyContainer.networkService)
    private let caidRepository: ClientAnalyticsIdRepository = resolve(\PrivyContainer.caidRepository)

    func logEvent(_ analyticsEvent: AnalyticsEvent) async throws {
        var request = try await networkService.makeRequest(path: "/api/v1/analytics_events", token: nil)

        let clientId = await caidRepository.loadClientId()

        let body = [
            "event_name": analyticsEvent.name,
            "client_id": clientId,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Analytics request expects empty response body
        let _: EmptyResponse = try await request.execute()
    }
}

private extension AnalyticsEvent {
    var name: String {
        switch self {
        case .sdkInitialize:
            "sdk_initialize"
        }
    }
}
