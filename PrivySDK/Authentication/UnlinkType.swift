import Foundation

internal enum UnlinkType {
    case email(address: String)
    case phone(phoneNumber: String)
    case siwe(address: String)
    case oauth(provider: OAuthProvider, subject: String)
}
