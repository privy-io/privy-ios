import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var loginWithEmail: Factory<LoginWithEmail> {
        self { LoginWithEmailImpl() }.shared
    }
}

private final class LoginWithEmailImpl: LoginWithEmail {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    func sendCode(to email: String) async throws {
        do {
            // send OTP to email, method will throw error if unsuccessful
            try await authManager.sendOtp(to: .email(email: email))
            logger.debug("Successfully sent OTP to \(email)")
        } catch {
            logger.debug("Error sending OTP to email: \(error.localizedDescription)")
            throw error
        }
    }

    func loginWithCode(_ code: String, sentTo email: String) async throws -> PrivyUser {
        logger.debug("Attempting to login user with email")

        return try await executeEmailAuth {
            try await authManager.login(with: .email(email, code: code))
        }
    }

    func linkWithCode(_ code: String, sentTo email: String) async throws -> PrivyUser {
        logger.debug("Attempting to link user's email")

        // ensure user is authenticated before linking
        let _ = try authManager.ensureAuthenticated()

        return try await executeEmailAuth {
            try await authManager.linkAccount(with: .email(email, code: code))
        }
    }

    func unlink(email: String) async throws -> PrivyUser {
        logger.debug("Attempting to unlink an email from the user")

        let _ = try authManager.ensureAuthenticated()

        return try await authManager.unlinkAccount(with: .email(address: email))
    }

    func updateWithCode(_ code: String, sentTo email: String) async throws {
        logger.debug("Attempting to update user's email")

        // ensure user is authenticated before updating
        let _ = try authManager.ensureAuthenticated()

        try await authManager.updateEmail(to: email, with: code)
    }

    func transferWithCode(nonce: String, code: String, sentTo email: String) async throws -> PrivyUser {
        logger.debug("Attempting to transfer email account")

        let _ = try authManager.ensureAuthenticated()

        return try await executeEmailAuth {
            try await authManager.transferAccount(with: .email(address: email, code: code, nonce: nonce))
        }
    }

    private func executeEmailAuth<T>(_ authCall: () async throws -> T) async throws -> T {
        do {
            return try await authCall()
        } catch ApiError.networkError(let responseCode, _) where responseCode == 422 {
            // If API threw 422 response, user inputted incorrect OTP
            logger.error("Incorrect OTP code inputted.", error: nil)
            throw PrivyError(.authenticationFailure(reason: .incorrectCredentials(loginMethod: .email)))
        } catch let privyError as PrivyError {
            // Already a typed PrivyError (e.g. accountTransferRequired, sessionExpired) — propagate
            // as-is rather than wrapping it in failureDuringAuthentication.
            throw privyError
        } catch {
            logger.error("Error authenticating user.", error: error)
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }
}
