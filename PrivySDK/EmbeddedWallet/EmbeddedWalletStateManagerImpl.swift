import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var embeddedWalletStateManager: Factory<EmbeddedWalletStateManager> {
        self { EmbeddedWalletStateManagerImpl() }.shared
    }
}

// State protected by an actor
private actor EmbeddedWalletStateManagerImpl: EmbeddedWalletStateManager {
    // Initial state is disconnected
    var state: EmbeddedWalletState = EmbeddedWalletState.disconnected

    func update(newState: EmbeddedWalletState) {
        self.state = newState
    }
}
