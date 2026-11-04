import Foundation

/// Specifies the original login method used for a particular auth session
public enum LoginMethod: Codable, Sendable {
    case customAccessToken
    case email
    case phone
    case siwe
    case siws
    case oauth
    case passkey
}
