import Foundation
internal import FactoryKit

/// Passkey-based MFA enrollment and verification
public protocol PrivyUserPasskeysMfa: Sendable {
    /// Passkey MFA enrollment operations
    var enroll: PrivyUserPasskeysMfaEnroll { get }

    /// Passkey MFA verification operations
    var verify: PrivyUserPasskeysMfaVerify { get }

    /// Unenroll passkey MFA.
    /// Requires prior MFA verification.
    /// - Parameters:
    ///   - removeForLogin: Whether to also unlink the passkey from login. Defaults to `true`.
    /// - Returns: The updated Privy user with the MFA method removed
    func unenroll(removeForLogin: Bool) async throws -> PrivyUser
}

extension PrivyUserPasskeysMfa {
    /// Unenroll passkey MFA, also unlinking it from login.
    /// Requires prior MFA verification.
    /// - Returns: The updated Privy user with the MFA method removed
    public func unenroll() async throws -> PrivyUser {
        try await unenroll(removeForLogin: true)
    }
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserPasskeysMfa: Factory<PrivyUserPasskeysMfa> {
        self { PrivyUserPasskeysMfaImpl() }.shared
    }
}

// MARK: - Implementation

private final class PrivyUserPasskeysMfaImpl: PrivyUserPasskeysMfa {
    private let repository: PasskeyMfaRepository = resolve(\PrivyContainer.passkeyMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal let enroll: PrivyUserPasskeysMfaEnroll = resolve(\PrivyContainer.privyUserPasskeysMfaEnroll)
    internal let verify: PrivyUserPasskeysMfaVerify = resolve(\PrivyContainer.privyUserPasskeysMfaVerify)

    internal func unenroll(removeForLogin: Bool) async throws -> PrivyUser {
        let auth = try authManager.ensureAuthenticated()
        // Unenroll by passing empty credentialIds with mfaToken
        try await ongoingMfaManager.withMfaHandling { mfaToken in
            guard let mfaToken else {
                throw PrivyError(.embeddedWalletFailure(reason: .missingOrInvalidMfa))
            }
            try await repository.enroll(
                credentialIds: [],
                removeForLogin: removeForLogin,
                authToken: auth.authToken,
                mfaToken: mfaToken
            )
        }

        // Clear token after unenrollment for security
        await mfaTokenRepository.delete()

        _ = try await authManager.refreshUser()
        return PrivyContainer.shared.privyUser()
    }
}
