import Foundation

internal protocol ClientAnalyticsIdRepository: Sendable {
    func loadClientId() async -> String

    func resetClientId() async
}
