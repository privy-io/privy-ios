import Foundation
internal import FactoryKit

/// SMS-based MFA enrollment and verification
public protocol PrivyUserSmsMfa: Sendable {
    /// SMS MFA enrollment operations
    var enroll: PrivyUserSmsMfaEnroll { get }

    /// SMS MFA verification operations
    var verify: PrivyUserSmsMfaVerify { get }

    /// Unenroll SMS MFA.
    /// Requires prior MFA verification.
    /// - Returns: The updated Privy user with the MFA method removed
    func unenroll() async throws -> PrivyUser
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserSmsMfa: Factory<PrivyUserSmsMfa> {
        self { PrivyUserSmsMfaImpl() }.shared
    }
}

// MARK: - Implementation

private final class PrivyUserSmsMfaImpl: PrivyUserSmsMfa {
    private let repository: SmsMfaRepository = resolve(\PrivyContainer.smsMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal let enroll: PrivyUserSmsMfaEnroll = resolve(\PrivyContainer.privyUserSmsMfaEnroll)
    internal let verify: PrivyUserSmsMfaVerify = resolve(\PrivyContainer.privyUserSmsMfaVerify)

    internal func unenroll() async throws -> PrivyUser {
        let auth = try authManager.ensureAuthenticated()
        try await ongoingMfaManager.withMfaHandling { mfaToken in
            guard let mfaToken else {
                throw PrivyError(.embeddedWalletFailure(reason: .missingOrInvalidMfa))
            }
            try await repository.unenroll(authToken: auth.authToken, mfaToken: mfaToken)
        }
        _ = try await authManager.refreshUser()

        // Clear token after unenrollment for security
        await mfaTokenRepository.delete()

        return PrivyContainer.shared.privyUser()
    }
}
