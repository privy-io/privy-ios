import Foundation
internal import FactoryKit

/// Namespace providing access to different MFA methods
public protocol PrivyUserMfa: Sendable {
    /// TOTP-based MFA
    var totp: PrivyUserTotpMfa { get }
    /// SMS-based MFA
    var sms: PrivyUserSmsMfa { get }
    /// Passkey-based MFA
    var passkeys: PrivyUserPasskeysMfa { get }
}

extension PrivyContainer {
    internal var privyUserMfa: Factory<PrivyUserMfa> {
        self { PrivyUserMfaImpl() }.shared
    }
}

private final class PrivyUserMfaImpl: PrivyUserMfa {
    internal let totp: PrivyUserTotpMfa = resolve(\PrivyContainer.privyUserTotpMfa)
    internal let sms: PrivyUserSmsMfa = resolve(\PrivyContainer.privyUserSmsMfa)
    internal let passkeys: PrivyUserPasskeysMfa = resolve(\PrivyContainer.privyUserPasskeysMfa)
}
