import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class InternalAuthStateManagerImplTests: PrivyTestCase {
    private var stateManager: InternalAuthStateManager!

    override internal func setUp() {
        super.setUp()
        self.stateManager = resolve(\PrivyContainer.internalAuthStateManager)
    }

    /// `InternalAuthState` isn't `Equatable`, so tests compare a short label instead.
    private func label(_ state: InternalAuthState) -> String {
        switch state {
        case .notReady: "notReady"
        case .unauthenticated: "unauthenticated"
        case .authenticatedUnverified: "authenticatedUnverified"
        case .authenticated(let session): "authenticated(\(session.user.id))"
        }
    }

    // MARK: state

    internal func testInitialStateIsNotReady() {
        XCTAssertEqual(label(stateManager.state), "notReady")
        XCTAssertFalse(stateManager.state.isConfirmedAuthenticated)
    }

    internal func testUpdateIsReflectedSynchronously() {
        stateManager.update(state: .unauthenticated)
        XCTAssertEqual(label(stateManager.state), "unauthenticated")

        stateManager.update(state: .authenticated(.test(userId: "user-1")))
        XCTAssertEqual(label(stateManager.state), "authenticated(user-1)")
        XCTAssertTrue(stateManager.state.isConfirmedAuthenticated)
    }

    internal func testOnlyAuthenticatedIsConfirmedAuthenticated() {
        XCTAssertFalse(InternalAuthState.notReady.isConfirmedAuthenticated)
        XCTAssertFalse(InternalAuthState.unauthenticated.isConfirmedAuthenticated)
        XCTAssertFalse(InternalAuthState.authenticatedUnverified(.init()).isConfirmedAuthenticated)
        XCTAssertTrue(InternalAuthState.authenticated(.test()).isConfirmedAuthenticated)
    }

    // MARK: stateStream

    internal func testStreamReplaysCurrentStateToNewSubscriber() async {
        stateManager.update(state: .unauthenticated)

        var iterator = stateManager.stateStream.makeAsyncIterator()

        let first = await iterator.next()
        XCTAssertEqual(first.map(label), "unauthenticated")
    }

    internal func testStreamEmitsSubsequentUpdatesInOrder() async {
        var iterator = stateManager.stateStream.makeAsyncIterator()

        stateManager.update(state: .unauthenticated)
        stateManager.update(state: .authenticated(.test(userId: "user-1")))

        let emitted = [await iterator.next(), await iterator.next(), await iterator.next()]
        XCTAssertEqual(emitted.map { $0.map(label) }, ["notReady", "unauthenticated", "authenticated(user-1)"])
    }

    internal func testEachAccessReturnsAnIndependentStream() async {
        var first = stateManager.stateStream.makeAsyncIterator()
        var second = stateManager.stateStream.makeAsyncIterator()

        stateManager.update(state: .unauthenticated)

        // Both consumers see every state; consuming one doesn't drain the other.
        let firstEmitted = [await first.next(), await first.next()]
        let secondEmitted = [await second.next(), await second.next()]
        XCTAssertEqual(firstEmitted.map { $0.map(label) }, ["notReady", "unauthenticated"])
        XCTAssertEqual(secondEmitted.map { $0.map(label) }, ["notReady", "unauthenticated"])
    }

    internal func testLateSubscriberOnlySeesLatestState() async {
        stateManager.update(state: .unauthenticated)
        stateManager.update(state: .authenticated(.test(userId: "user-1")))

        var iterator = stateManager.stateStream.makeAsyncIterator()

        let first = await iterator.next()
        XCTAssertEqual(first.map(label), "authenticated(user-1)")
    }

    internal func testCancellingConsumerStopsStreamWithoutAffectingState() async {
        let stream = stateManager.stateStream
        let consumer = Task { () -> Int in
            var count = 0
            for await _ in stream { count += 1 }
            return count
        }
        consumer.cancel()
        _ = await consumer.value

        stateManager.update(state: .unauthenticated)

        XCTAssertEqual(label(stateManager.state), "unauthenticated")
    }
}
