import Foundation

/// Methods used to login with a phone number or linking one to the current user.
public protocol LoginWithSms: Sendable {
    /// Sends an OTP to the user via SMS.
    ///
    /// - Parameters:
    ///   - phoneNumber: The phone number to send the OTP to
    ///
    /// - Throws: An error if sending OTP is not successful
    func sendCode(to phoneNumber: String) async throws

    /// Logs the user in.
    ///
    /// - Parameters:
    ///   - code: The OTP sent to the user
    ///   - phoneNumber: Phone number the OTP was sent to
    ///
    /// - Returns: The authenticated Privy user
    ///
    /// - Throws: An error if logging the user in is unsuccessful
    func loginWithCode(_ code: String, sentTo phoneNumber: String) async throws -> PrivyUser

    /// Links the user's phone number to the users account. User must be authenticated prior to calling this method.
    ///
    /// - Parameters:
    ///   - code: The OTP sent to the user
    ///   - phoneNumber: Phone number the OTP was sent to
    ///
    /// - Returns: The updated Privy user with the newly linked phone number
    ///
    /// - Throws: An error if linking the user's phone number in is unsuccessful, or if there is no authenticated
    ///   user. If the phone number is already owned by a different user with only one login method, this throws
    ///   ``PrivyErrorCode/AuthenticationFailureReason/accountTransferRequired(nonce:conflictingUser:)`` instead —
    ///   catch it and call ``transferWithCode(nonce:code:sentTo:)`` with its nonce to complete the transfer. Note
    ///   that this will not transfer wallets from the other account.
    func linkWithCode(_ code: String, sentTo phoneNumber: String) async throws -> PrivyUser

    /// Updates the user's phone number.
    ///
    /// - Parameters:
    ///   - code: The OTP sent to the user
    ///   - phoneNumber: The new phone number for the user.
    ///
    /// - Throws: An error if updating the user's phone number is unsuccessful
    func updateWithCode(_ code: String, sentTo phoneNumber: String) async throws

    /// Unlinks a phone number from the user's account. User must be authenticated prior to calling this method.
    ///
    /// - Parameters:
    ///   - phoneNumber: Phone number to unlink from the user's account
    ///
    /// - Returns: The updated Privy user after unlinking the phone number
    func unlink(phoneNumber: String) async throws -> PrivyUser

    /// Transfers a conflicting phone number account to the current user.
    ///
    /// Call this after catching a ``PrivyError`` with errorCode
    /// ``PrivyErrorCode/AuthenticationFailureReason/accountTransferRequired(nonce:conflictingUser:)``
    /// from ``linkWithCode(_:sentTo:)``. The user must already be authenticated.
    ///
    /// Note: this only transfers the SMS login method. It will not transfer any embedded wallets
    /// from the other account — those remain with the other user and are not merged.
    ///
    /// - Parameters:
    ///   - nonce: The one-time transfer nonce from the `accountTransferRequired` error.
    ///   - code: The OTP sent to the phone number.
    ///   - phoneNumber: The phone number the OTP was sent to.
    ///
    /// - Returns: The updated ``PrivyUser`` if transfer succeeded.
    ///
    /// - Throws: An error if the transfer fails or if there is no authenticated user.
    func transferWithCode(nonce: String, code: String, sentTo phoneNumber: String) async throws -> PrivyUser
}
