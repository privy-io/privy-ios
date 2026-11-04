import Foundation
internal import FactoryKit

/// SMS MFA enrollment operations
public protocol PrivyUserSmsMfaEnroll: Sendable {
    /// Send an OTP code to a phone number for enrollment.
    /// Requires prior MFA verification (if a method is already enrolled).
    /// - Parameters:
    ///   - phoneNumber: Phone number to send code to
    func sendCode(to phoneNumber: String) async throws

    /// Submit the verification code to complete SMS MFA enrollment.
    /// - Parameters:
    ///   - code: OTP code received via SMS
    ///   - phoneNumber: Phone number that received the code
    /// - Returns: The updated Privy user with the newly enrolled MFA method
    func submit(code: String, sentTo phoneNumber: String) async throws -> PrivyUser
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserSmsMfaEnroll: Factory<PrivyUserSmsMfaEnroll> {
        self { PrivyUserSmsMfaEnrollImpl() }.shared
    }
}

// MARK: - Implementation

internal final class PrivyUserSmsMfaEnrollImpl: PrivyUserSmsMfaEnroll {
    private let repository: SmsMfaRepository = resolve(\PrivyContainer.smsMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let userSignerRepository: UserSignerRepository = resolve(\PrivyContainer.userSignerRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let webViewHandler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal func sendCode(to phoneNumber: String) async throws {
        let auth = try authManager.ensureAuthenticated()
        try await ongoingMfaManager.withMfaHandling { mfaToken in
            try await repository.initialize(phoneNumber: phoneNumber, authToken: auth.authToken, mfaToken: mfaToken)
        }
    }

    internal func submit(code: String, sentTo phoneNumber: String) async throws -> PrivyUser {
        let auth = try authManager.ensureAuthenticated()
        _ = try await repository.enroll(phoneNumber: phoneNumber, code: code, authToken: auth.authToken)

        // Clear token after enrollment for security
        await mfaTokenRepository.delete()

        // Clear user signing key to trigger MFA on next wallet action
        await userSignerRepository.clearUserSigner()

        _ = try await authManager.refreshUser()
        return PrivyContainer.shared.privyUser()
    }
}
