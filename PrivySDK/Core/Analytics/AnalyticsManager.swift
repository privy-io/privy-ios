internal import FactoryKit

internal protocol AnalyticsManager: Sendable {
    func logEvent(_ event: AnalyticsEvent) async throws
}

extension PrivyContainer {
    internal var analyticsManager: Factory<AnalyticsManager> {
        self { AnalyticsManagerImpl() }.shared
    }
}

private final class AnalyticsManagerImpl: AnalyticsManager {
    private let analyticsRepository: AnalyticsRepository = resolve(\PrivyContainer.analyticsRepository)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    init() {
        // Log initialize event when SDK is first initialized
        Task {
            do {
                try await self.logEvent(.sdkInitialize)
                logger.infoInternal("Privy init analytics event sent")
            } catch {
                logger.errorInternal("Privy init analytics event error", error: error)
            }
        }
    }

    func logEvent(_ event: AnalyticsEvent) async throws {
        try await analyticsRepository.logEvent(event)
    }
}
