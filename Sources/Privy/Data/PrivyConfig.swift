//
//  PrivyConfig.swift
//  
//
//  Created by Dalu Udeogu on 2023-11-22.
//

import Foundation


/// The Privy app configuration
public struct PrivyConfig {

    /// The app ID that can be retrieved from the developer dashboard
    public let appId: String

    public init(appId: String) {
        self.appId = appId
    }
}
