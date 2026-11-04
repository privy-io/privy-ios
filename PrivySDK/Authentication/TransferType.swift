import Foundation

internal enum TransferType {
    case email(address: String, code: String, nonce: String)
    case phone(phoneNumber: String, code: String, nonce: String)
    case oauth(provider: OAuthProvider, authorizationCode: String, codeVerifier: String, stateCode: String, nonce: String)
    case siwe(params: SiweLoginParams, nonce: String)
    case siws(message: String, signature: String, walletAddress: String, walletClientType: WalletClientType?, connectorType: String?, nonce: String)
}
