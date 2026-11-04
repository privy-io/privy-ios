import Foundation
@testable import PrivySDK

/// In-memory `InternalAuthStateManager` test double. Unlike the real implementation,
/// `stateStream` returns the same `AsyncStream` on every access rather than a fresh one, since
/// tests only ever need a single consumer.
internal final class TestInternalAuthStateManager: InternalAuthStateManager, @unchecked Sendable {
    internal private(set) var state: InternalAuthState
    internal private(set) var updateRequests: [InternalAuthState] = []

    private let stream: AsyncStream<InternalAuthState>
    private let continuation: AsyncStream<InternalAuthState>.Continuation

    internal init(state: InternalAuthState = .notReady) {
        self.state = state
        (self.stream, self.continuation) = AsyncStream.makeStream(of: InternalAuthState.self)
    }

    internal var stateStream: AsyncStream<InternalAuthState> { stream }

    internal func update(state: InternalAuthState) {
        self.state = state
        updateRequests.append(state)
        continuation.yield(state)
    }
}
