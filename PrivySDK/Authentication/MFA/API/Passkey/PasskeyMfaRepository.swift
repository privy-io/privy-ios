import Foundation
internal import FactoryKit

internal protocol PasskeyMfaRepository: Sendable {
    /// Get passkey authentication options for MFA verification
    func initialize(relyingParty: String, authToken: String) async throws -> PasskeyMfaInitResponse

    /// Enroll or update passkey MFA credential IDs
    func enroll(credentialIds: [String], removeForLogin: Bool, authToken: String, mfaToken: String?) async throws

    /// Verify passkey and get MFA token
    func verify(
        credential: PasskeyAuthenticationCredential,
        relyingParty: String,
        authToken: String
    ) async throws -> MfaVerifyResponse
}

extension PrivyContainer {
    internal var passkeyMfaRepository: Factory<PasskeyMfaRepository> {
        self { PasskeyMfaRepositoryImpl() }.shared
    }
}

private final class PasskeyMfaRepositoryImpl: PasskeyMfaRepository {
    private let networkService: NetworkService = resolve(\PrivyContainer.networkService)

    func initialize(relyingParty: String, authToken: String) async throws -> PasskeyMfaInitResponse {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/passkeys/init", token: authToken)
        request.httpBody = try JSONEncoder().encode(PasskeyMfaInitRequest(relyingParty: relyingParty))
        return try await request.execute()
    }

    func enroll(credentialIds: [String], removeForLogin: Bool, authToken: String, mfaToken: String?) async throws {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/passkeys/enrollment", token: authToken)
        if let mfaToken {
            request.setValue(mfaToken, forHTTPHeaderField: "privy-mfa-token")
        }
        request.httpBody = try JSONEncoder().encode(
            PasskeyMfaEnrollmentRequest(credentialIds: credentialIds, removeForLogin: removeForLogin)
        )
        let _: EmptyResponse = try await request.execute()
    }

    func verify(
        credential: PasskeyAuthenticationCredential,
        relyingParty: String,
        authToken: String
    ) async throws -> MfaVerifyResponse {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/passkeys/verify", token: authToken)
        let body = PasskeyMfaVerifyRequest(
            authenticatorResponse: credential,
            relyingParty: relyingParty
        )
        request.httpBody = try JSONEncoder().encode(body)
        return try await request.execute()
    }
}
