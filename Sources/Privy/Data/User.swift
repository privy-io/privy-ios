//
//  User.swift
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

/// The user object representing an authenticated user
public struct User {

    /// The user id
    public let id: String

    /// All linked accounts on the user. Linked Account can be a wallet
    public let linkedAccount: [Account]
}
