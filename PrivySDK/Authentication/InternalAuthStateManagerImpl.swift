import Foundation
@preconcurrency import Combine
internal import FactoryKit

extension PrivyContainer {
    internal var internalAuthStateManager: Factory<InternalAuthStateManager> {
        self { InternalAuthStateManagerImpl() }.shared
    }
}

private final class InternalAuthStateManagerImpl: InternalAuthStateManager {
    // Even though publish subjects technically don't adhere to Strict concurrency, there is a severe limitation
    // that an AsyncStream can only be consumed by one consumer at a time and AsyncStreams do not hold state.
    // By using a CurrentValueSubject internally, we can manage state + expose a new AsyncStream that subscribes
    // to this CurrentValueSubject each time it's requested. This gives the illusion of multi consumer AysncStreams.
    // https://abdulahd1996.medium.com/using-async-stream-and-combine-together-b80b835e629e
    private let internalAuthStateSubject = CurrentValueSubject<InternalAuthState, Never>(.notReady)

    public var state: InternalAuthState {
        get {
            internalAuthStateSubject.value
        }
    }

    public var statePublisher: AnyPublisher<InternalAuthState, Never> {
        internalAuthStateSubject.eraseToAnyPublisher()
    }

    func update(state: InternalAuthState) {
        internalAuthStateSubject.send(state)
    }

    public var stateStream: AsyncStream<InternalAuthState> {
        // Important: this must be a computed property (i.e. get {}), not a stored property, because it
        // creates a new AsyncStream each time it's referenced. This is important because Async streams
        // only support single consumer
        get {
            AsyncStream { continuation in
                let cancellable = self.internalAuthStateSubject.sink { continuation.yield($0) }

                continuation.onTermination = { continuation in
                    cancellable.cancel()
                }
            }
        }
    }
}
