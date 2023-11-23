//
//  User.swift
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

/// The user object representing an authenticated user
public struct User: Identifiable {

    /// The user id
    public let id: String

    /// All linked accounts on the user. Linked Account can be a wallet
    public let linkedAccounts: [any Account]
}

extension User: Equatable {
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id && lhs.linkedAccounts.count == rhs.linkedAccounts.count
    }
}
