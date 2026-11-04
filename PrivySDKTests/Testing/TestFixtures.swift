import Foundation
@testable import PrivySDK

/// Minimal, valid instances of internal models that tests need to hand back from a test double
/// but don't care about the contents of.
extension InternalAuthSession {
    internal static func test(
        userId: String = "test-user-id",
        authToken: String = "test-auth-token",
        linkedAccounts: [LinkedAccount] = [],
        loginMethod: LoginMethod = .email
    ) -> InternalAuthSession {
        InternalAuthSession(
            user: InternalPrivyUser(id: userId, createdAt: Date(timeIntervalSince1970: 0), linkedAccounts: linkedAccounts, mfaMethods: []),
            authToken: authToken,
            refreshToken: "test-refresh-token",
            identityToken: nil,
            loginMethod: loginMethod
        )
    }
}

extension AuthSessionTokens {
    internal static func test(
        authToken: String = "stored-auth-token",
        refreshToken: String = "stored-refresh-token",
        loginMethod: LoginMethod = .email
    ) -> AuthSessionTokens {
        AuthSessionTokens(authToken: authToken, refreshToken: refreshToken, identityToken: nil, loginMethod: loginMethod)
    }
}

extension String {
    /// An unsigned JWT whose `exp` claim is `expiresIn` seconds from now. Note that the SDK treats a
    /// token as expired 60 seconds before its `exp`.
    internal static func testJwt(expiresIn seconds: TimeInterval) -> String {
        func encode(_ object: [String: Any]) -> String {
            // swiftlint:disable:next force_try
            let data = try! JSONSerialization.data(withJSONObject: object)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return [
            encode(["alg": "none", "typ": "JWT"]),
            encode(["exp": Date().timeIntervalSince1970 + seconds]),
            "signature",
        ].joined(separator: ".")
    }
}

extension UserResponse {
    internal static func test(userId: String = "test-user-id") -> UserResponse {
        UserResponse(id: userId, createdAt: .test(), linkedAccounts: [], mfaMethods: [])
    }
}

extension RefreshUserResponse {
    internal static func test(userId: String = "test-user-id", identityToken: String? = nil) -> RefreshUserResponse {
        RefreshUserResponse(
            user: UserResponse(id: userId, createdAt: .test(), linkedAccounts: [], mfaMethods: []),
            identityToken: identityToken
        )
    }
}

extension PasskeyRegistrationApiOptions {
    internal static func test(challenge: String = "test-challenge") -> PasskeyRegistrationApiOptions {
        PasskeyRegistrationApiOptions(
            challenge: challenge,
            rp: ApiRelyingParty(id: "example.com", name: "Example"),
            user: ApiUserInfo(id: "test-user-id", name: "user@example.com", displayName: "User"),
            pubKeyCredParams: [ApiPubKeyCredParam(type: "public-key", alg: -7)],
            timeout: nil,
            excludeCredentials: nil,
            authenticatorSelection: nil,
            attestation: nil
        )
    }
}

extension PasskeyAuthenticationApiOptions {
    internal static func test(challenge: String = "test-challenge") -> PasskeyAuthenticationApiOptions {
        PasskeyAuthenticationApiOptions(
            challenge: challenge,
            timeout: nil,
            rpId: "example.com",
            allowCredentials: nil,
            userVerification: nil
        )
    }
}

extension PasskeyRegistrationCredential {
    internal static func test(id: String = "test-credential-id") -> PasskeyRegistrationCredential {
        PasskeyRegistrationCredential(
            type: "public-key",
            id: id,
            rawId: id,
            response: AuthenticatorAttestationResponse(
                clientDataJSON: "client-data",
                attestationObject: "attestation",
                transports: nil,
                publicKeyAlgorithm: nil,
                publicKey: nil,
                authenticatorData: nil
            ),
            authenticatorAttachment: nil,
            clientExtensionResults: [:]
        )
    }
}

extension PasskeyAuthenticationCredential {
    internal static func test(id: String = "test-credential-id") -> PasskeyAuthenticationCredential {
        PasskeyAuthenticationCredential(
            type: "public-key",
            id: id,
            rawId: id,
            response: AuthenticatorAssertionResponse(
                clientDataJSON: "client-data",
                authenticatorData: "authenticator-data",
                signature: "signature",
                userHandle: nil
            ),
            authenticatorAttachment: nil,
            clientExtensionResults: [:]
        )
    }
}

extension GenerateSiweMessageResponse {
    internal static func test(nonce: String = "test-nonce", address: String = "0xabc") -> GenerateSiweMessageResponse {
        GenerateSiweMessageResponse(nonce: nonce, address: address, expiresAt: "2030-01-01T00:00:00.000Z")
    }
}

extension SiwsInitResponseBody {
    internal static func test(nonce: String = "test-nonce", address: String = "SoLaNaAddress") -> SiwsInitResponseBody {
        SiwsInitResponseBody(nonce: nonce, address: address, expiresAt: "2030-01-01T00:00:00.000Z")
    }
}

extension OAuthInitResponse {
    internal static func test(url: String = "https://oauth.example.com/authorize") -> OAuthInitResponse {
        OAuthInitResponse(url: url)
    }
}

extension AuthResponse {
    internal static func test(
        userId: String = "test-user-id",
        sessionUpdateAction: SessionUpdateAction = .set(accessToken: "new-auth-token", refreshToken: "new-refresh-token", identityToken: nil)
    ) -> AuthResponse {
        var token: String?
        var refreshToken: String?
        if case .set(let accessToken, let newRefreshToken, _) = sessionUpdateAction {
            token = accessToken
            refreshToken = newRefreshToken
        }
        return AuthResponse(
            user: UserResponse(id: userId, createdAt: .test(), linkedAccounts: [], mfaMethods: []),
            token: token,
            refreshToken: refreshToken,
            identityToken: nil,
            sessionUpdateAction: sessionUpdateAction
        )
    }
}

extension SecondsSinceEpoch {
    /// `SecondsSinceEpoch` can only be built by decoding, so decode a bare number.
    internal static func test(_ seconds: TimeInterval = 0) -> SecondsSinceEpoch {
        // swiftlint:disable:next force_try
        try! JSONDecoder().decode(SecondsSinceEpoch.self, from: Data("\(seconds)".utf8))
    }
}

extension EmbeddedEthereumWalletAccount {
    /// A TEE wallet. `hdWalletIndex` and `imported` default to the user's Privy HD primary.
    internal static func test(
        id: String? = "ethereum-wallet-id",
        address: String = "0x1111111111111111111111111111111111111111",
        hdWalletIndex: Int = 0,
        imported: Bool = false
    ) -> EmbeddedEthereumWalletAccount {
        EmbeddedEthereumWalletAccount(
            id: id,
            address: address,
            recoveryMethod: "privy-v2",
            firstVerifiedAt: nil,
            latestVerifiedAt: nil,
            hdWalletIndex: hdWalletIndex,
            imported: imported,
            userCanSign: true
        )
    }
}

extension EmbeddedSolanaWalletAccount {
    /// A TEE wallet. `hdWalletIndex` and `imported` default to the user's Privy HD primary.
    internal static func test(
        id: String? = "solana-wallet-id",
        address: String = "SoLanaWa11etA111111111111111111111111111111",
        hdWalletIndex: Int = 0,
        imported: Bool = false
    ) -> EmbeddedSolanaWalletAccount {
        EmbeddedSolanaWalletAccount(
            id: id,
            address: address,
            recoveryMethod: "privy-v2",
            firstVerifiedAt: nil,
            latestVerifiedAt: nil,
            hdWalletIndex: hdWalletIndex,
            imported: imported,
            userCanSign: true
        )
    }
}
