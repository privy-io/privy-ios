import Foundation

internal enum LoginType {
    case customAccessToken(token: String)
    case email(_ email: String, code: String)
    case phone(_ phoneNumber: String, code: String)
    case siwe(params: SiweLoginParams)
    case oauth(provider: OAuthProvider, authorizationCode: String, codeVerifier: String, stateCode: String)
    case passkeyRegistration(credential: PasskeyRegistrationCredential, relyingParty: String)
    case passkeyAuthentication(credential: PasskeyAuthenticationCredential, challenge: String, relyingParty: String)
}

internal struct SiweLoginParams {
    internal let message: String
    internal let signature: String
    internal let chainId: String
    internal let walletAddress: String
    internal let walletClientType: WalletClientType?
    internal let connectorType: String?
}

internal extension LoginType {
    func toLoginMethod() -> LoginMethod {
        switch self {
        case .customAccessToken:
            .customAccessToken
        case .email:
            .email
        case .phone:
            .phone
        case .siwe:
            .siwe
        case .oauth:
            .oauth
        case .passkeyRegistration, .passkeyAuthentication:
            .passkey
        }
    }
}
