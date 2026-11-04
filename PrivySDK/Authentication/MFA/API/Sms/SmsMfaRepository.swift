import Foundation
internal import FactoryKit

internal protocol SmsMfaRepository: Sendable {
    /// Initialize SMS MFA - sends OTP to phone number (enrollment) or enrolled phone (verification)
    func initialize(phoneNumber: String?, authToken: String, mfaToken: String?) async throws

    /// Enroll SMS MFA with verification code
    func enroll(phoneNumber: String, code: String, authToken: String) async throws -> UserResponse

    /// Unenroll SMS MFA (requires MFA token)
    func unenroll(authToken: String, mfaToken: String) async throws

    /// Verify SMS code and get MFA token
    func verify(code: String, authToken: String) async throws -> MfaVerifyResponse
}

extension PrivyContainer {
    internal var smsMfaRepository: Factory<SmsMfaRepository> {
        self { SmsMfaRepositoryImpl() }.shared
    }
}

private final class SmsMfaRepositoryImpl: SmsMfaRepository {
    private let networkService: NetworkService = resolve(\PrivyContainer.networkService)

    func initialize(phoneNumber: String?, authToken: String, mfaToken: String?) async throws {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/passwordless_sms/init", token: authToken)
        if let mfaToken {
            request.setValue(mfaToken, forHTTPHeaderField: "privy-mfa-token")
        }
        if let phoneNumber {
            request.httpBody = try JSONEncoder().encode(SmsMfaInitEnrollRequest(phoneNumber: phoneNumber))
        } else {
            request.httpBody = try JSONEncoder().encode(SmsMfaInitVerifyRequest())
        }
        let _: EmptyResponse = try await request.execute()
    }

    func enroll(phoneNumber: String, code: String, authToken: String) async throws -> UserResponse {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/passwordless_sms/enroll", token: authToken)
        request.httpBody = try JSONEncoder().encode(SmsMfaEnrollRequest(code: code, phoneNumber: phoneNumber))
        return try await request.execute()
    }

    func unenroll(authToken: String, mfaToken: String) async throws {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/passwordless_sms/unenroll", token: authToken)
        request.setValue(mfaToken, forHTTPHeaderField: "privy-mfa-token")
        let _: EmptyResponse = try await request.execute()
    }

    func verify(code: String, authToken: String) async throws -> MfaVerifyResponse {
        var request = try await networkService.makeRequest(path: "/api/v1/mfa/passwordless_sms/verify", token: authToken)
        request.httpBody = try JSONEncoder().encode(SmsMfaVerifyRequest(code: code))
        return try await request.execute()
    }
}
