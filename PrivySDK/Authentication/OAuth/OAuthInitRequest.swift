import Foundation

internal struct OAuthInitRequest {
    internal let provider: OAuthProvider
    internal let redirectUri: String
    internal let codeChallenge: String
    internal let stateCode: String
    internal let authToken: String?
}
