import Foundation
internal import FactoryKit

/// Passkey MFA enrollment operations
public protocol PrivyUserPasskeysMfaEnroll: Sendable {
    /// Submit passkey credential IDs to complete passkey MFA enrollment.
    /// - Parameters:
    ///   - credentialIds: IDs of passkeys to use for MFA
    /// - Returns: The updated Privy user with the newly enrolled MFA method
    func submit(credentialIds: [String]) async throws -> PrivyUser
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserPasskeysMfaEnroll: Factory<PrivyUserPasskeysMfaEnroll> {
        self { PrivyUserPasskeysMfaEnrollImpl() }.shared
    }
}

// MARK: - Implementation

internal final class PrivyUserPasskeysMfaEnrollImpl: PrivyUserPasskeysMfaEnroll {
    private let repository: PasskeyMfaRepository = resolve(\PrivyContainer.passkeyMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let userSignerRepository: UserSignerRepository = resolve(\PrivyContainer.userSignerRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let webViewHandler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal func submit(credentialIds: [String]) async throws -> PrivyUser {
        let auth = try authManager.ensureAuthenticated()
        try await ongoingMfaManager.withMfaHandling { mfaToken in
            try await repository.enroll(
                credentialIds: credentialIds,
                removeForLogin: false,
                authToken: auth.authToken,
                mfaToken: mfaToken
            )
        }

        // Clear token after enrollment for security
        await mfaTokenRepository.delete()

        // Clear user signing key to trigger MFA on next wallet action
        await userSignerRepository.clearUserSigner()

        _ = try await authManager.refreshUser()
        return PrivyContainer.shared.privyUser()
    }
}
