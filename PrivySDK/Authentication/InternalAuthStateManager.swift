import Foundation

/*
 * Manages internal auth state.
 *
 * Ideally, we make this an actor down the line. We can't do it now because our public API requires
 * synchronous access to these values.
 */
internal protocol InternalAuthStateManager: Sendable {
    var state: InternalAuthState { get }

    func update(state: InternalAuthState)

    /// Auth state updates via AsyncStream
    /// Returns a new AsyncStream each time this is called
    var stateStream: AsyncStream<InternalAuthState> { get }
}
