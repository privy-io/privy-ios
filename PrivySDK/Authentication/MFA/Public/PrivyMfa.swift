import Foundation
internal import FactoryKit

/// Entry point for MFA operations at the Privy level.
///
/// Access this via `privy.mfa` to manage blocked MFA operations.
public protocol PrivyMfa: Sendable {
    /// Sets the MFA configuration for handling MFA prompts.
    ///
    /// Use this to configure a delegate that will be called when operations require
    /// MFA verification, and to set the timeout for MFA verification.
    ///
    /// This configuration takes precedence over any `PrivyMFAConfig` provided
    /// in the initial `PrivyConfig`.
    ///
    /// - Parameter config: The MFA configuration to use.
    func setConfig(_ config: PrivyMFAConfig)

    /// Resumes any operations that were blocked waiting for MFA verification.
    ///
    /// Call this method after successfully verifying MFA (via `user.mfa.totp.verify.submit`,
    /// `user.mfa.sms.verify.submit`, or `user.mfa.passkeys.verify.submit`) to unblock
    /// pending wallet operations.
    ///
    /// In the case that successful MFA verification is not possible (e.g. user cancelled,
    /// or there too many attempts), this method MUST be called regardless, with a `(throwing: error)`
    /// in order to unblock operations.
    ///
    /// If this method is not called, blocked operations will eventually time out.
    ///
    /// - Parameters:
    ///   - error: If provided, all blocked operations will throw this error instead of resuming successfully.
    func resumeBlockedActions(throwing error: Error?) async
}

public extension PrivyMfa {
    /// Resumes any operations that were blocked waiting for MFA verification.
    ///
    /// Call this method after successfully verifying MFA (via `user.mfa.totp.verify.submit`,
    /// `user.mfa.sms.verify.submit`, or `user.mfa.passkeys.verify.submit`) to unblock
    /// pending wallet operations.
    ///
    /// In the case that successful MFA verification is not possible (e.g. user cancelled,
    /// or there too many attempts), this method MUST be called regardless, with a `(throwing: error)`
    /// in order to unblock operations.
    ///
    /// If this method is not called, blocked operations will eventually time out.
    func resumeBlockedActions() async {
        await resumeBlockedActions(throwing: nil)
    }
}

extension PrivyContainer {
    internal var privyMfa: Factory<PrivyMfa> {
        self { PrivyMfaImpl() }.shared
    }
}

private final class PrivyMfaImpl: PrivyMfa {
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)

    internal func setConfig(_ config: PrivyMFAConfig) {
        PrivyContainer.shared.mfaConfig.register { config }
    }

    internal func resumeBlockedActions(throwing error: Error?) async {
        await ongoingMfaManager.resolveAll(throwing: error)
    }
}
