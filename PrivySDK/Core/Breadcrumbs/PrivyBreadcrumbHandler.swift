/// Receives ``PrivyBreadcrumb`` events emitted by the Privy SDK. Called synchronously on emit.
public protocol PrivyBreadcrumbHandler: Sendable {
    /// Called synchronously on the emitting thread. Implementations must not block.
    func receive(_ breadcrumb: PrivyBreadcrumb)
}
