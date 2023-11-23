//
//  Account.swift
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

/// A protocol for an account
public protocol Account: Identifiable, Equatable {

    /// The id of the account
    var id: String { get }
}
