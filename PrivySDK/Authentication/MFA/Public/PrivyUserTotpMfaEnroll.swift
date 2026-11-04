import Foundation
internal import FactoryKit

/// TOTP MFA enrollment operations
public protocol PrivyUserTotpMfaEnroll: Sendable {
    /// Generate a TOTP secret for authenticator app enrollment.
    /// Requires prior MFA verification (if a method is already enrolled).
    /// - Returns: Secret and auth URL for QR code generation
    func generateSecret() async throws -> TotpSecret

    /// Submit the verification code from the authenticator app to complete TOTP MFA enrollment.
    /// - Parameters:
    ///   - code: 6-digit TOTP code
    /// - Returns: The updated Privy user with the newly enrolled MFA method
    func submit(code: String) async throws -> PrivyUser
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserTotpMfaEnroll: Factory<PrivyUserTotpMfaEnroll> {
        self { PrivyUserTotpMfaEnrollImpl() }.shared
    }
}

// MARK: - Implementation

internal final class PrivyUserTotpMfaEnrollImpl: PrivyUserTotpMfaEnroll {
    private let repository: TotpMfaRepository = resolve(\PrivyContainer.totpMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let userSignerRepository: UserSignerRepository = resolve(\PrivyContainer.userSignerRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let webViewHandler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal func generateSecret() async throws -> TotpSecret {
        let auth = try authManager.ensureAuthenticated()
        return try await ongoingMfaManager.withMfaHandling { mfaToken in
            let response = try await repository.initialize(authToken: auth.authToken, mfaToken: mfaToken)
            return TotpSecret(from: response)
        }
    }

    internal func submit(code: String) async throws -> PrivyUser {
        let auth = try authManager.ensureAuthenticated()
        _ = try await repository.enroll(code: code, authToken: auth.authToken)

        // Clear token after enrollment for security
        await mfaTokenRepository.delete()

        // Clear user signing key to trigger MFA on next wallet action
        await userSignerRepository.clearUserSigner()

        _ = try await authManager.refreshUser()
        return PrivyContainer.shared.privyUser()
    }
}
