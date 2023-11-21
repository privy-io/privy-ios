//
//  EmbeddedWalletState.swift
//  HeadlessSDK
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

/// The different State of the embedded wallet
public enum EmbeddedWalletState {
    case connecting
    case connnected(EmbeddedWalletProvider)
    case notCreated(WalletCreator)
    case needsRecovery
    case error
}



