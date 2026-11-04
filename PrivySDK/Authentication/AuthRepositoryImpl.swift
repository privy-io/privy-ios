import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var authRepository: Factory<AuthRepository> {
        self { AuthRepositoryImpl() }.shared
    }
}

private final class AuthRepositoryImpl: AuthRepository {
    private let networkService: NetworkService = resolve(\PrivyContainer.networkService)

    internal func sendOtp(to otpRequestType: OtpRequestType) async throws {
        var request = try await self.networkService.makeRequest(path: "/api/v1/\(otpRequestType.apiPath)/init", token: nil)

        request.httpBody = try JSONSerialization.data(withJSONObject: otpRequestType.requestBody, options: [])

        let result: OtpInitResponse = try await request.execute()

        if result.success {
            // sent otp successfully, return from function
            return
        } else {
            // error sending otp, propagate up via error
            // this should likely never happen - our backend returns a 200 response with success hard coded
            // to true if sent successfully. if otp wasn't sent successfully, backend returns 4XX, which would
            // throw at request.execute above
            let loginMethod = if case .email = otpRequestType { LoginMethod.email } else { LoginMethod.phone }
            throw PrivyError(.authenticationFailure(reason: .incorrectCredentials(loginMethod: loginMethod)))
        }
    }

    internal func generateSiweMessage(walletAddress: String) async throws -> GenerateSiweMessageResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/siwe/init", token: nil)

        let requestBody = ["address": walletAddress]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        return try await request.execute()
    }

    internal func siwsInit(_ requestBody: SiwsInitRequestBody) async throws -> SiwsInitResponseBody {
        var request = try await self.networkService.makeRequest(path: "/api/v1/siws/init", token: nil)
        request.httpBody = try JSONEncoder().encode(requestBody)
        return try await request.execute()
    }

    internal func siwsAuthenticate(_ requestBody: SiwsAuthenticateRequestBody) async throws -> AuthResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/siws/authenticate", token: nil)
        request.httpBody = try JSONEncoder().encode(requestBody)
        return try await request.execute()
    }

    internal func siwsLink(_ requestBody: SiwsLinkRequestBody, authToken: String) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/siws/link", token: authToken)
        request.httpBody = try JSONEncoder().encode(requestBody)
        return try await request.execute()
    }

    internal func siwsUnlink(_ requestBody: SiwsUnlinkRequestBody, authToken: String) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/siws/unlink", token: authToken)
        request.httpBody = try JSONEncoder().encode(requestBody)
        return try await request.execute()
    }

    internal func unlinkPasskey(credentialId: String, removeAsMfa: Bool, authToken: String, mfaToken: String?) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passkeys/unlink", token: authToken)
        if let mfaToken {
            request.setValue(mfaToken, forHTTPHeaderField: "privy-mfa-token")
        }
        request.httpBody = try JSONEncoder().encode(UnlinkPasskeyRequest(credentialId: credentialId, removeAsMfa: removeAsMfa))
        return try await request.execute()
    }

    internal func generateOAuthUrl(oAuthInitRequest: OAuthInitRequest) async throws -> OAuthInitResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/oauth/init", token: oAuthInitRequest.authToken)

        let requestBody = [
            "provider": oAuthInitRequest.provider.requestBodyName,
            "redirect_to": oAuthInitRequest.redirectUri,
            "code_challenge": oAuthInitRequest.codeChallenge,
            "state_code": oAuthInitRequest.stateCode,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        return try await request.execute()
    }

    internal func authenticate(with loginType: LoginType) async throws -> AuthResponse {
        switch loginType {
        case .passkeyRegistration(let credential, let relyingParty):
            // Handle passkey registration slightly different than other authenticate flows
            return try await authenticatePasskeyRegistration(credential: credential, relyingParty: relyingParty)
        case .passkeyAuthentication(let credential, let challenge, let relyingParty):
            return try await authenticatePasskeyAuthentication(credential: credential, challenge: challenge, relyingParty: relyingParty)
        default:
            var request = try await self.networkService.makeRequest(path: "/api/v1/\(loginType.apiPath)/authenticate", token: nil)
            request.httpBody = try JSONSerialization.data(withJSONObject: loginType.requestBody, options: [])

            do {
                return try await request.execute()
            } catch let backendError as AccountTransferBackendError {
                throw backendError
            } catch {
                throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
            }
        }
    }

    private func authenticatePasskeyAuthentication(
        credential: PasskeyAuthenticationCredential,
        challenge: String,
        relyingParty: String
    ) async throws -> AuthResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passkeys/authenticate", token: nil)

        let passkeyRequest = PasskeyAuthenticateRequest(
            authenticatorResponse: credential,
            challenge: challenge,
            relyingParty: relyingParty
        )

        request.httpBody = try JSONEncoder().encode(passkeyRequest)

        do {
            return try await request.execute()
        } catch let backendError as AccountTransferBackendError {
            throw backendError
        } catch {
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }

    private func authenticatePasskeyRegistration(credential: PasskeyRegistrationCredential, relyingParty: String) async throws -> AuthResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passkeys/register", token: nil)

        let passkeyRequest = PasskeyRegisterRequest(
            authenticatorResponse: credential,
            relyingParty: relyingParty
        )
        request.httpBody = try JSONEncoder().encode(passkeyRequest)

        do {
            return try await request.execute()
        } catch let backendError as AccountTransferBackendError {
            throw backendError
        } catch {
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }

    // So far, the link API is exactly the same as authenticate API, so we are reusing "LoginType"
    // Since "LoginType" is internal to PrivySDK, we can always change this method if APIs diverge
    internal func link(with loginType: LoginType, authToken: String) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/\(loginType.apiPath)/link", token: authToken)
        request.httpBody = try JSONSerialization.data(withJSONObject: loginType.requestBody, options: [])

        return try await request.execute()
    }

    internal func transfer(with transferType: TransferType, authToken: String) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/\(transferType.apiPath)/transfer", token: authToken)
        request.httpBody = try JSONSerialization.data(withJSONObject: transferType.requestBody, options: [])

        return try await request.execute()
    }

    internal func unlink(with unlinkType: UnlinkType, authToken: String) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/\(unlinkType.apiPath)/unlink", token: authToken)
        request.httpBody = try JSONSerialization.data(withJSONObject: unlinkType.requestBody, options: [])

        return try await request.execute()
    }

    internal func refreshSession(token: String, refreshToken: String) async throws -> AuthResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/sessions", token: token)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken], options: [])

        return try await request.execute()
    }

    internal func refreshUser(token: String) async throws -> RefreshUserResponse {
        let request = try await self.networkService.makeRequest(path: "/api/v1/users/me", token: token, httpMethod: "GET")

        return try await request.execute()
    }

    internal func logoutSession(authToken: String) async throws {
        let request = try await self.networkService.makeRequest(path: "/api/v1/sessions/logout", token: authToken)

        let _: EmptyResponse = try await request.execute()
    }

    internal func updateEmail(from oldAddress: String, to newAddress: String, with code: String, authToken: String) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passwordless/update", token: authToken)

        let requestBody = [
            "oldAddress": oldAddress,
            "newAddress": newAddress,
            "code": code,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        return try await request.execute()
    }

    internal func updatePhoneNumber(from oldPhoneNumber: String, to newPhoneNumber: String, with code: String, authToken: String) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passwordless_sms/update", token: authToken)

        // For legacy reasons, this endpoint (unlike others) expects a snake_case body
        let requestBody = [
            "old_phone_number": oldPhoneNumber,
            "new_phone_number": newPhoneNumber,
            "code": code,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        return try await request.execute()
    }

    internal func generatePasskeyRegistrationOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passkeys/register/init", token: nil)

        let requestBody = ["relying_party": relyingParty.absoluteString]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        let response: InitPasskeyRegistrationApiResponse = try await request.execute()
        return response.options
    }

    internal func generatePasskeyAuthenticationOptions(relyingParty: URL) async throws -> PasskeyAuthenticationApiOptions {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passkeys/authenticate/init", token: nil)

        let requestBody = ["relying_party": relyingParty.absoluteString]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        let response: PasskeyAuthenticationOptionsResponse = try await request.execute()
        return response.options
    }

    internal func generatePasskeyLinkOptions(relyingParty: URL, authToken: String) async throws -> PasskeyRegistrationApiOptions {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passkeys/link/init", token: authToken)

        let requestBody = ["relying_party": relyingParty.absoluteString]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        let response: InitPasskeyRegistrationApiResponse = try await request.execute()
        return response.options
    }

    internal func linkPasskey(credential: PasskeyRegistrationCredential, relyingParty: String, authToken: String) async throws -> UserResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/passkeys/link", token: authToken)

        let passkeyRequest = PasskeyRegisterRequest(
            authenticatorResponse: credential,
            relyingParty: relyingParty
        )
        request.httpBody = try JSONEncoder().encode(passkeyRequest)

        return try await request.execute()
    }
}

private extension Data {
    func asString() -> String? {
        return String(data: self, encoding: String.Encoding.utf8)
    }
}

private extension UnlinkType {
    var apiPath: String {
        return switch self {
        case .email(_):
            "passwordless"
        case .phone(_):
            "passwordless_sms"
        case .siwe(_):
            "siwe"
        case .oauth(_, _):
            "oauth"
        }
    }

    var requestBody: [String: String] {
        return switch self {
        case .email(let address):
            ["address": address]
        case .phone(let phoneNumber):
            ["phoneNumber": phoneNumber]
        case .siwe(let address):
            ["address": address]
        case .oauth(let provider, let subject):
            ["provider": provider.requestBodyName, "subject": subject]
        }
    }
}

private extension TransferType {
    var apiPath: String {
        return switch self {
        case .email:
            "passwordless"
        case .phone:
            "passwordless_sms"
        case .oauth:
            "oauth"
        case .siwe:
            "siwe"
        case .siws:
            "siws"
        }
    }

    var requestBody: [String: String] {
        return switch self {
        case .email(let address, let code, let nonce):
            ["email": address, "code": code, "nonce": nonce]
        case .phone(let phoneNumber, let code, let nonce):
            ["phoneNumber": phoneNumber, "code": code, "nonce": nonce]
        case .oauth(provider: .apple, authorizationCode: let authorizationCode, codeVerifier: let codeVerifier, stateCode: let stateCode, nonce: let nonce):
            ["authorization_code": authorizationCode, "code_verifier": codeVerifier, "state_code": stateCode, "code_type": "raw", "nonce": nonce]
        case .oauth(provider: _, authorizationCode: let authorizationCode, codeVerifier: let codeVerifier, stateCode: let stateCode, nonce: let nonce):
            ["authorization_code": authorizationCode, "code_verifier": codeVerifier, "state_code": stateCode, "nonce": nonce]
        case .siwe(let params, let nonce):
            params.toTransferRequestBody(nonce: nonce)
        case .siws(let message, let signature, let walletAddress, let walletClientType, let connectorType, let nonce):
            TransferType.siwsRequestBody(message: message, signature: signature, walletAddress: walletAddress, walletClientType: walletClientType, connectorType: connectorType, nonce: nonce)
        }
    }

    private static func siwsRequestBody(
        message: String,
        signature: String,
        walletAddress: String,
        walletClientType: WalletClientType?,
        connectorType: String?,
        nonce: String
    ) -> [String: String] {
        var body = ["address": walletAddress, "message": message, "message_type": "plain", "signature": signature, "nonce": nonce]

        if let walletClientType = walletClientType {
            body["walletClientType"] = walletClientType.rawValue
        }

        if let connectorType = connectorType {
            body["connectorType"] = connectorType
        }

        return body
    }
}

private extension LoginType {
    var apiPath: String {
        return switch self {
        case .customAccessToken(_):
            "custom_jwt_account"
        case .email(_, _):
            "passwordless"
        case .phone(_, _):
            "passwordless_sms"
        case .siwe(_):
            "siwe"
        case .oauth:
            "oauth"
        case .passkeyRegistration:
            "passkeys/register"
        case .passkeyAuthentication:
            "passkeys"
        }
    }

    var requestBody: [String: String] {
        return switch self {
        case .customAccessToken(let token):
            ["token": token]
        case .email(let email, let code):
            ["email": email, "code": code]
        case .phone(let phoneNumber, let code):
            ["phoneNumber": phoneNumber, "code": code]
        case .siwe(let loginParams):
            loginParams.toRequestBody()
        case .oauth(provider: .apple, authorizationCode: let authorizationCode, codeVerifier: let codeVerifier, stateCode: let stateCode):
            ["authorization_code": authorizationCode, "code_verifier": codeVerifier, "state_code": stateCode, "code_type": "raw"]
        case .oauth(provider: _, authorizationCode: let authorizationCode, codeVerifier: let codeVerifier, stateCode: let stateCode):
            ["authorization_code": authorizationCode, "code_verifier": codeVerifier, "state_code": stateCode]
        case .passkeyRegistration, .passkeyAuthentication:
            // Passkey types don't use simple string request bodies, they need JSON encoding
            // This will be handled separately in authenticate() method
            [:]
        }
    }
}

private extension SiweLoginParams {
    func toRequestBody() -> [String: String] {
        var body = [
            "message": message,
            "signature": signature,
            "chainId": chainId,
        ]

        if let walletClientType = walletClientType {
            body["walletClientType"] = walletClientType.rawValue
        }

        if let connectorType = connectorType {
            body["connectorType"] = connectorType
        }

        return body
    }

    func toTransferRequestBody(nonce: String) -> [String: String] {
        var body = toRequestBody()
        body["address"] = walletAddress
        body["nonce"] = nonce
        return body
    }
}

private extension OtpRequestType {
    var apiPath: String {
        return switch self {
        case .email(_):
            "passwordless"
        case .phone(_):
            "passwordless_sms"
        }
    }

    var requestBody: [String: String] {
        return switch self {
        case .email(let email):
            ["email": email]
        case .phone(let phoneNumber):
            ["phoneNumber": phoneNumber]
        }
    }
}

private struct OtpInitResponse: Decodable {
    public let success: Bool
}

private struct UnlinkPasskeyRequest: Encodable {
    let credentialId: String
    let removeAsMfa: Bool

    private enum CodingKeys: String, CodingKey {
        case credentialId = "credential_id"
        case removeAsMfa = "remove_as_mfa"
    }
}

private extension OAuthProvider {
    var requestBodyName: String {
        switch self {
        case .google:
            "google"
        case .apple:
            "apple"
        case .twitter:
            "twitter"
        case .discord:
            "discord"
        case .telegram:
            "telegram"
        }
    }
}
