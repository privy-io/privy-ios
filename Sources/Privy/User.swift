//
//  User.swift
//  HeadlessSDK
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

/// The user object from the backend
public struct User {

    /// the user id
    let id: String

    /// all linked accounts on the user
    let linkedAccount: [Account]
}
