import Foundation
@testable import PrivySDK

/// In-memory `BreadcrumbEmitter` test double that records every emitted breadcrumb for assertions.
internal final class TestBreadcrumbEmitter: BreadcrumbEmitter, @unchecked Sendable {
    internal private(set) var emitted: [PrivyBreadcrumb] = []

    internal func emit(_ breadcrumb: PrivyBreadcrumb) {
        emitted.append(breadcrumb)
    }
}
