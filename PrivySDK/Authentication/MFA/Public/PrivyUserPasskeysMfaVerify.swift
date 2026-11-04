import Foundation
internal import FactoryKit

/// Passkey MFA verification operations
public protocol PrivyUserPasskeysMfaVerify: Sendable {
    /// Submit passkey verification using the specified relying party.
    /// - Parameters:
    ///   - relyingParty: The origin that owns the credentials (e.g., "https://yourdomain.com")
    func submit(relyingParty: String) async throws
}

// MARK: - Factory Registration

extension PrivyContainer {
    internal var privyUserPasskeysMfaVerify: Factory<PrivyUserPasskeysMfaVerify> {
        self { PrivyUserPasskeysMfaVerifyImpl() }.shared
    }
}

// MARK: - Implementation

internal final class PrivyUserPasskeysMfaVerifyImpl: PrivyUserPasskeysMfaVerify {
    private let repository: PasskeyMfaRepository = resolve(\PrivyContainer.passkeyMfaRepository)
    private let mfaTokenRepository: MfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let passkeyHandler: PasskeyHandler = resolve(\PrivyContainer.passkeyHandler)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal func submit(relyingParty: String) async throws {
        let auth = try authManager.ensureAuthenticated()
        do {
            // Get authentication options from server
            let initResponse = try await repository.initialize(relyingParty: relyingParty, authToken: auth.authToken)

            // Use PasskeyHandler to prompt for biometric authentication
            let credential = try await passkeyHandler.getCredential(authenticationOptions: initResponse.options)

            // Verify the credential with the server
            let response = try await repository.verify(
                credential: credential,
                relyingParty: relyingParty,
                authToken: auth.authToken
            )
            try await mfaTokenRepository.save(mfaToken: response.token)
        } catch {
            // Clear token on failure for security
            await mfaTokenRepository.delete()
            // Map to the standard MFA error form if needed
            throw mapErrorIfMfa(error)
        }
    }
}
