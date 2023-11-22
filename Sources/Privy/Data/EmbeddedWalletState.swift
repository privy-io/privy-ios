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



