//
//  EmbeddedWalletState.swift
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

/// The different states of the embedded wallet
public enum EmbeddedWalletState {
    case connecting
    case connected(EmbeddedWalletProvider)
    case notCreated(WalletCreator)
    case needsRecovery
    case error
}

extension EmbeddedWalletState: Equatable {
    public static func == (lhs: EmbeddedWalletState, rhs: EmbeddedWalletState) -> Bool {
        switch (lhs, rhs) {
        case (.connected(let lhsProvider), .connected(let rhsProvider)):
            return lhsProvider == rhsProvider
        case (.notCreated(let lhsCreator), .notCreated(let rhsCreator)):
            return lhsCreator == rhsCreator
        case (.connecting, .connecting):
            return true
        case (.needsRecovery, .needsRecovery):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
