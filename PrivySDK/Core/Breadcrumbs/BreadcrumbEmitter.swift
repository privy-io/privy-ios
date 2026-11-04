internal import FactoryKit

extension PrivyContainer {
    internal var breadcrumbEmitter: Factory<BreadcrumbEmitter> {
        self { BreadcrumbEmitterImpl() }.shared
    }
}

/// Single entry point for emitting ``PrivyBreadcrumb`` events. Relays every emitted breadcrumb
/// synchronously to the consumer-registered ``PrivyBreadcrumbHandler``, if any.
internal protocol BreadcrumbEmitter: Sendable {
    func emit(_ breadcrumb: PrivyBreadcrumb)
}

private final class BreadcrumbEmitterImpl: BreadcrumbEmitter {
    func emit(_ breadcrumb: PrivyBreadcrumb) {
        PrivyContainer.shared.config().breadcrumbHandler?.receive(breadcrumb)
    }
}
