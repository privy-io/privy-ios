import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var loginWithPasskey: Factory<LoginWithPasskey> {
        self { LoginWithPasskeyImpl() }.shared
    }
}

private final class LoginWithPasskeyImpl: LoginWithPasskey {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let passkeyHandler: PasskeyHandler = resolve(\PrivyContainer.passkeyHandler)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    func signup(relyingParty: String, displayName: String?) async throws -> PrivyUser {
        logger.debug("Attempting to register passkey for relying party: \(relyingParty)")

        do {
            let relyingPartyUrl = try toValidRelyingPartyUrl(relyingParty: relyingParty)

            // Request registration options from server
            let apiRegistrationOptions = try await authManager.generatePasskeyRegistrationOptions(relyingParty: relyingPartyUrl)

            // Create passkey
            logger.debug("Creating passkey credential")
            let credential = try await passkeyHandler.createCredential(
                registrationOptions: apiRegistrationOptions,
                overrideDisplayName: displayName
            )

            logger.debug("Submitting passkey credential to server")
            return try await authManager.login(with: .passkeyRegistration(credential: credential, relyingParty: relyingParty))
        } catch {
            logger.error("Error during passkey signup", error: error)
            throw error
        }
    }

    func login(relyingParty: String) async throws -> PrivyUser {
        logger.debug("Attempting to authenticate with passkey for relying party: \(relyingParty)")

        do {
            let relyingPartyUrl = try toValidRelyingPartyUrl(relyingParty: relyingParty)

            // Request authentication options from server
            let authenticationOptions = try await authManager.generatePasskeyAuthenticationOptions(relyingParty: relyingPartyUrl)

            // Get credential from platform
            logger.debug("Retrieving passkey credential")
            let credential = try await passkeyHandler.getCredential(authenticationOptions: authenticationOptions)

            // Submit credential to server and authenticate
            logger.debug("Submitting passkey credential to server")

            let user = try await authManager.login(with: .passkeyAuthentication(
                credential: credential,
                challenge: authenticationOptions.challenge,
                relyingParty: relyingParty
            ))

            logger.debug("Successfully authenticated with passkey")
            return user
        } catch {
            logger.error("Error during passkey login", error: error)
            throw error
        }
    }

    func link(relyingParty: String, displayName: String?) async throws -> PrivyUser {
        logger.debug("Attempting to link passkey for relying party: \(relyingParty)")

        do {
            // Ensure user is authenticated before linking
            _ = try authManager.ensureAuthenticated()

            let relyingPartyUrl = try toValidRelyingPartyUrl(relyingParty: relyingParty)

            // Request link options from server
            let apiRegistrationOptions = try await authManager.generatePasskeyLinkOptions(relyingParty: relyingPartyUrl)

            // Create passkey
            logger.debug("Creating passkey credential")
            let credential = try await passkeyHandler.createCredential(
                registrationOptions: apiRegistrationOptions,
                overrideDisplayName: displayName
            )

            // Submit credential to link passkey to authenticated user
            logger.debug("Submitting passkey credential to server")
            let user = try await authManager.linkPasskey(credential: credential, relyingParty: relyingParty)

            logger.debug("Successfully linked passkey")
            return user
        } catch {
            logger.error("Error during passkey link", error: error)
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }

    func unlink(credentialId: String, removeAsMfa: Bool) async throws -> PrivyUser {
        do {
            logger.verbose("Unlinking passkey.")
            // ensure user is authenticated before unlinking
            _ = try authManager.ensureAuthenticated()
            return try await authManager.unlinkPasskey(credentialId: credentialId, removeAsMfa: removeAsMfa)
        } catch {
            logger.error("Error unlinking passkey", error: error)
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }

    private func toValidRelyingPartyUrl(relyingParty: String) throws -> URL {
        guard let relyingPartyUrl = relyingParty.safeParse() else {
            throw PrivyError(.authenticationFailure(reason: .passkeyCreationFailed("Invalid relying party URL")))
        }

        return relyingPartyUrl
    }
}

private extension String {
    func safeParse() -> URL? {
        guard let url = URL(string: self) else {
            // relyingParty must be a valid URL
            return nil
        }

        if url.scheme == "https" {
            return url
        }

        if url.scheme == "http" && url.host == "localhost" {
            return url
        }

        return nil
    }
}
