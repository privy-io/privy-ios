import Foundation
internal import FactoryKit

/// TOTP MFA verification operations
public protocol PrivyUserTotpMfaVerify: Sendable {
    /// Submit the verification code from the authenticator app to verify TOTP MFA.
    /// - Parameters:
    ///   - code: 6-digit TOTP code
    func submit(code: String) async throws
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserTotpMfaVerify: Factory<PrivyUserTotpMfaVerify> {
        self { PrivyUserTotpMfaVerifyImpl() }.shared
    }
}

// MARK: - Implementation

internal final class PrivyUserTotpMfaVerifyImpl: PrivyUserTotpMfaVerify {
    private let repository: TotpMfaRepository = resolve(\PrivyContainer.totpMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

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
