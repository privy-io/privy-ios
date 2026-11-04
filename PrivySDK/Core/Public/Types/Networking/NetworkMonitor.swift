import Foundation
import Network
internal import FactoryKit

internal protocol NetworkMonitor: Sendable {
    /// Stream of network connectivity status
    var connectivityStream: AsyncStream<Bool> { get }
}

extension PrivyContainer {
    internal var networkMonitor: Factory<NetworkMonitor> {
        self { NWPathNetworkMonitor() }.unique
    }
}

private final class NWPathNetworkMonitor: NetworkMonitor {
    private let logger: Logger = resolve(\PrivyContainer.logger)
    private let queue = DispatchQueue(label: "privy.network.monitor", qos: .background)

    var connectivityStream: AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()

            monitor.start(queue: queue)
            logger.verbose("Network monitoring started")

            monitor.pathUpdateHandler = { path in
                let isConnected = path.status == .satisfied
                continuation.yield(isConnected)
            }

            continuation.onTermination = { [weak self] _ in
                self?.logger.verbose("Network monitoring stopped")
                monitor.cancel()
            }
        }
    }
}
