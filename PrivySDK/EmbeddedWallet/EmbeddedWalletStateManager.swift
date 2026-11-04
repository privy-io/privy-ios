import Foundation

internal protocol EmbeddedWalletStateManager: Actor {
    var state: EmbeddedWalletState { get }

    func update(newState: EmbeddedWalletState)
}
