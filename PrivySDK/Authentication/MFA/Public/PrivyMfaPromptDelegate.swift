import Foundation

/// A delegate protocol for handling MFA prompts.
///
/// Implement this protocol to get notified on when to prompt your user for MFA when operations
/// require it. When configured via `privy.mfa.setConfig(_:)` or `PrivyMFAConfig`, the SDK will
/// automatically call `onMfaRequired(for:)` when an operation fails due to missing MFA.
/// In this case, you should prompt the end user based on `user.mfaMethods`, calling
/// verification methods like `user.mfa.totp.verify.submit`.
/// Once MFA has been verified you MUST call `privy.mfa.resumeBlockedActions()`
/// to ensure the operations being awaited can finalize correctly.
///
/// ## Basic usage
/// ### Set up the delegate
/// ```swift
/// class MyMfaHandler: PrivyMfaPromptDelegate {
///     func onMfaRequired(for user: PrivyUser) {
///         // Show your custom MFA UI. This runs in the main actor.
///         showMfaPromptUI()
///     }
/// }
///
/// let mfaConfig = PrivyMFAConfig(
///     delegate: MyMfaHandler()
/// )
///
/// let config = PrivyConfig(
///     appId: "your-app-id",
///     appClientId: "your-client-id",
///     mfaConfig: mfaConfig
/// )
/// ```
///
/// ### Calling actions on wallets
///
/// Acting on wallets can be done as usual, via its provider.
///
/// ```swift
/// try await wallet.provider.request(.personalSign(...))
/// ```
///
/// This async method call will be STUCK until MFA is verified (see below)
///
/// ### Verifying MFA and resuming operations
///
/// Once your `PrivyMfaPromptDelegate.onMfaRequired`  method has been called and
/// you have guided the user through a custom UI for MFA, you must call the following:
///
/// ```swift
/// // Verify using the appropriate MFA method
/// try await user.mfa.totp.verify.submit(code: code)
/// // Resume any blocked operations
/// await privy.mfa.resumeBlockedActions()
/// ```
///
/// This ensures that (after `verify.submit` has completed) the SDK is notified (via `resumeBlockedActions`)
/// that the blocked actions can retry and unblock.
///
/// ## Possible flows
/// ### MFA verification succeeds
/// If your call to `verify.submit` has completed successfully you must ensure `privy.mfa.resumeBlockedActions`
/// is called so the wallet actions you are waiting on can be completed.
///
/// ### MFA verification is canceled or unavailable
/// If the user decides to cancel the MFA flow or otherwise fails to verify their MFA (e.g. passkey unavailable),
/// you must still call `privy.mfa.resumeBlockedActions` so the blocked wallet operations can
/// continue (and fail!).
///
/// ### Timeout
/// If `privy.mfa.resumeBlockedActions` is not called in the 5 minutes following the wallet operation that
/// triggered the delegate in the first place, the original wallet opeartion will throw (without retrying) with a
/// `timeoutOnMfa` error.
public protocol PrivyMfaPromptDelegate: Sendable {
    /// Called when an operation requires MFA verification.
    ///
    /// Implement this method to present MFA UI to the user and call one of
    /// the MFA verification methods (e.g. `user.mfa.totp.verify.submit`).
    ///
    /// This method is called for every operation that requires MFA, and may be called
    /// concurrently if multiple operations need MFA at the same time. Your implementation
    /// should handle being called multiple times (e.g. by showing a single MFA prompt and
    /// ignoring subsequent calls while it's visible). Once MFA has been successfully verified,
    /// this method will not be called again until MFA needs to be validated again.
    ///
    /// Always called on the `@MainActor`.
    ///
    /// - Parameters:
    ///   - user: The currently authenticated Privy user who needs to verify MFA.
    @MainActor
    func onMfaRequired(for user: PrivyUser)
}
