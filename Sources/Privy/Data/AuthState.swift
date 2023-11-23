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

extension AuthState: Equatable {
    public static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.authenticated(let lhsUser, let lhsState), .authenticated(let rhsUser, let rhsState)):
            return lhsUser == rhsUser && lhsState == rhsState
        case (.unauthenticated, .unauthenticated):
            return true
        default:
            return false
        }
    }
}
