import Foundation
internal import FactoryKit

/// TOTP-based MFA enrollment and verification
public protocol PrivyUserTotpMfa: Sendable {
    /// TOTP MFA enrollment operations
    var enroll: PrivyUserTotpMfaEnroll { get }

    /// TOTP MFA verification operations
    var verify: PrivyUserTotpMfaVerify { get }

    /// Unenroll TOTP MFA.
    /// Requires prior MFA verification.
    /// - Returns: The updated Privy user with the MFA method removed
    func unenroll() async throws -> PrivyUser
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserTotpMfa: Factory<PrivyUserTotpMfa> {
        self { PrivyUserTotpMfaImpl() }.shared
    }
}

// MARK: - Implementation

private final class PrivyUserTotpMfaImpl: PrivyUserTotpMfa {
    private let repository: TotpMfaRepository = resolve(\PrivyContainer.totpMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal let enroll: PrivyUserTotpMfaEnroll = resolve(\PrivyContainer.privyUserTotpMfaEnroll)
    internal let verify: PrivyUserTotpMfaVerify = resolve(\PrivyContainer.privyUserTotpMfaVerify)

    internal func unenroll() async throws -> PrivyUser {
        let auth = try authManager.ensureAuthenticated()
        try await ongoingMfaManager.withMfaHandling { mfaToken in
            guard let mfaToken else {
                throw PrivyError(.embeddedWalletFailure(reason: .missingOrInvalidMfa))
            }
            try await repository.unenroll(authToken: auth.authToken, mfaToken: mfaToken)
        }

        // Clear token after unenrollment for security
        await mfaTokenRepository.delete()

        _ = try await authManager.refreshUser()
        return PrivyContainer.shared.privyUser()
    }
}
