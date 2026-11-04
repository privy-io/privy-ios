import Foundation
internal import FactoryKit

internal protocol TotpMfaRepository: Sendable {
    /// Initialize TOTP enrollment - generates secret and auth URL
    func initialize(authToken: String, mfaToken: String?) async throws -> TotpInitResponse

    /// Enroll TOTP MFA with verification code
    func enroll(code: String, authToken: String) async throws -> UserResponse

    /// Unenroll TOTP MFA (requires MFA token)
    func unenroll(authToken: String, mfaToken: String) async throws

    /// Verify TOTP code and get MFA token
    func verify(code: String, authToken: String) async throws -> MfaVerifyResponse
}

extension PrivyContainer {
    internal var totpMfaRepository: Factory<TotpMfaRepository> {
        self { TotpMfaRepositoryImpl() }.shared
    }
}

private final class TotpMfaRepositoryImpl: TotpMfaRepository {
    private let networkService: NetworkService = resolve(\PrivyContainer.networkService)

    func initialize(authToken: String, mfaToken: String?) async throws -> TotpInitResponse {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/totp/init", token: authToken)
        if let mfaToken {
            request.setValue(mfaToken, forHTTPHeaderField: "privy-mfa-token")
        }
        return try await request.execute()
    }

    func enroll(code: String, authToken: String) async throws -> UserResponse {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/totp/enroll", token: authToken)
        request.httpBody = try JSONEncoder().encode(TotpCodeRequest(code: code))
        return try await request.execute()
    }

    func unenroll(authToken: String, mfaToken: String) async throws {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/totp/unenroll", token: authToken)
        request.setValue(mfaToken, forHTTPHeaderField: "privy-mfa-token")
        let _: EmptyResponse = try await request.execute()
    }

    func verify(code: String, authToken: String) async throws -> MfaVerifyResponse {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/totp/verify", token: authToken)
        request.httpBody = try JSONEncoder().encode(TotpCodeRequest(code: code))
        return try await request.execute()
    }
}
