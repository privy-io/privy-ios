//
//  AuthState.swift
//  
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

/// The user's authenticated state
public enum AuthState {
    case unauthenticated
    case authenticated(User, EmbeddedWalletState)
}
