import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var loginWithSms: Factory<LoginWithSms> {
        self { LoginWithSmsImpl() }.shared
    }
}

private final class LoginWithSmsImpl: LoginWithSms, Sendable {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    func sendCode(to phoneNumber: String) async throws {
        do {
            // send OTP to phone number, method will throw error if unsuccessful
            try await authManager.sendOtp(to: .phone(phoneNumber))
            logger.debug("Successfully sent OTP to \(phoneNumber)")
        } catch {
            logger.debug("Error sending OTP to \(phoneNumber): \(error.localizedDescription)")
            throw error
        }
    }

    func loginWithCode(_ code: String, sentTo phoneNumber: String) async throws -> PrivyUser {
        logger.debug("Attempting to login user with phone number.")

        return try await executeSmsAuth {
            try await authManager.login(with: .phone(phoneNumber, code: code))
        }
    }

    func linkWithCode(_ code: String, sentTo phoneNumber: String) async throws -> PrivyUser {
        logger.debug("Attempting to link user's phone number")

        // ensure user is authenticated before linking
        _ = try authManager.ensureAuthenticated()

        return try await executeSmsAuth {
            try await authManager.linkAccount(with: .phone(phoneNumber, code: code))
        }
    }

    func updateWithCode(_ code: String, sentTo phoneNumber: String) async throws {
        logger.debug("Attempting to update user's phone number")

        // ensure user is authenticated before updating
        let _ = try authManager.ensureAuthenticated()

        try await authManager.updatePhoneNumber(to: phoneNumber, with: code)
    }

    func unlink(phoneNumber: String) async throws -> PrivyUser {
        logger.debug("Attempting to unlink a phone number from the user")

        let _ = try authManager.ensureAuthenticated()

        return try await authManager.unlinkAccount(with: .phone(phoneNumber: phoneNumber))
    }

    func transferWithCode(nonce: String, code: String, sentTo phoneNumber: String) async throws -> PrivyUser {
        logger.debug("Attempting to transfer phone account")

        let _ = try authManager.ensureAuthenticated()

        return try await executeSmsAuth {
            try await authManager.transferAccount(with: .phone(phoneNumber: phoneNumber, code: code, nonce: nonce))
        }
    }

    private func executeSmsAuth<T>(_ authCall: () async throws -> T) async throws -> T {
        do {
            return try await authCall()
        } catch ApiError.networkError(let responseCode, _) where responseCode == 422 {
            // If API threw 422 response, user inputted incorrect OTP
            logger.error("Incorrect OTP code inputted.", error: nil)
            throw PrivyError(.authenticationFailure(reason: .incorrectCredentials(loginMethod: .phone)))
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
