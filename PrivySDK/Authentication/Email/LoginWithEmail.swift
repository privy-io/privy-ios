import Foundation

/// Methods used to login with an email account or linking one to the current user.
public protocol LoginWithEmail: Sendable {
    /// Sends an OTP to the user.
    ///
    /// - Parameters:
    ///   - email: The email to send the OTP to
    ///
    /// - Throws: An error if sending OTP is not successful
    func sendCode(to email: String) async throws

    /// Logs the user in.
    ///
    /// - Parameters:
    ///   - code: The OTP sent to the user
    ///   - email: Email the OTP was sent to.
    ///
    /// - Returns: The authenticated Privy user
    ///
    /// - Throws: An error if logging the user in is unsuccessful
    func loginWithCode(_ code: String, sentTo email: String) async throws -> PrivyUser

    /// Links the user's email to the users account. User must be authenticated prior to calling this method.
    ///
    /// - Parameters:
    ///   - code: The OTP sent to the user
    ///   - email: Email the OTP was sent to
    ///
    /// - Returns: The updated Privy user with the newly linked email
    ///
    /// - Throws: An error if linking the user's email in is unsuccessful, or if there is no authenticated user
    func linkWithCode(_ code: String, sentTo email: String) async throws -> PrivyUser

    /// Updates the user account with a new email address. User must be authenticated prior to calling this method.
    ///
    ///  - Parameters:
    ///      - code: The OTP sent to the new email address
    ///      - email: New email address the OTP was sent to
    ///  - Throws: An error if updating the user's email is unsuccessful, or if there is no authenticated user
    func updateWithCode(_ code: String, sentTo email: String) async throws

    /// Unlinks a linked email from the user's account. User must be authenticated prior to calling this method.
    ///
    /// - Parameters:
    ///   - email: Email to unlink from the user's account
    ///
    /// - Returns: The updated Privy user after unlinking the email
    func unlink(email: String) async throws -> PrivyUser

    /// Transfers a conflicting email account to the current user.
    ///
    /// Call this after catching a ``PrivyError`` with errorCode
    /// ``PrivyErrorCode/AuthenticationFailureReason/accountTransferRequired(nonce:conflictingUser:)``
    /// from ``linkWithCode(_:sentTo:)``. The user must already be authenticated.
    ///
    /// Note: this only transfers the email login method. It will not transfer any embedded wallets
    /// from the other account — those remain with the other user and are not merged.
    ///
    /// - Parameters:
    ///   - nonce: The one-time transfer nonce from the `accountTransferRequired` error.
    ///   - code: The OTP sent to the email address.
    ///   - email: The email address the OTP was sent to.
    ///
    /// - Returns: The updated ``PrivyUser`` if transfer succeeded.
    ///
    /// - Throws: An error if the transfer fails or if there is no authenticated user.
    func transferWithCode(nonce: String, code: String, sentTo email: String) async throws -> PrivyUser
}
