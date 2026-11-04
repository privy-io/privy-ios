import Foundation
internal import FactoryKit

/// SMS MFA verification operations
public protocol PrivyUserSmsMfaVerify: Sendable {
    /// Send an OTP code to the enrolled phone number for verification.
    func sendCode() async throws

    /// Submit the verification code to verify SMS MFA.
    /// - Parameters:
    ///   - code: OTP code received via SMS
    func submit(code: String) async throws
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserSmsMfaVerify: Factory<PrivyUserSmsMfaVerify> {
        self { PrivyUserSmsMfaVerifyImpl() }.shared
    }
}

// MARK: - Implementation

internal final class PrivyUserSmsMfaVerifyImpl: PrivyUserSmsMfaVerify {
    private let repository: SmsMfaRepository = resolve(\PrivyContainer.smsMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal func sendCode() async throws {
        let auth = try authManager.ensureAuthenticated()
        try await ongoingMfaManager.withMfaHandling { mfaToken in
            try await repository.initialize(phoneNumber: nil, authToken: auth.authToken, mfaToken: mfaToken)
        }
    }

    internal func submit(code: String) async throws {
        let auth = try authManager.ensureAuthenticated()
        do {
            let response = try await repository.verify(code: code, authToken: auth.authToken)
            try await mfaTokenRepository.save(mfaToken: response.token)
        } catch {
            // Clear token on failure for security
            await mfaTokenRepository.delete()
            // Map to the standard MFA error form if needed
            throw mapErrorIfMfa(error)
        }
    }
}
