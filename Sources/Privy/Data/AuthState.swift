//
//  AuthState.swift
//  
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

/// The users Auth State
public enum AuthState {
    case unauthenticated
    case authenticated(User, EmbeddedWalletState)
}
