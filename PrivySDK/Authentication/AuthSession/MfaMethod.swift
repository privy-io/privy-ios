import Foundation

/// An MFA method linked to the active user
public enum MfaMethod: Sendable {
    /// SMS-based MFA
    case sms(SmsMfaMethod)
    /// TOTP-based MFA
    case totp(TotpMfaMethod)
    /// Passkey-based MFA
    case passkey(PasskeyMfaMethod)
}

/// SMS-based MFA method
public struct SmsMfaMethod: Sendable {
    /// Date when the MFA method was verified
    public let verifiedAt: Date
}

/// TOTP-based MFA method
public struct TotpMfaMethod: Sendable {
    /// Date when the MFA method was verified
    public let verifiedAt: Date
}

/// Passkey-based MFA method
public struct PasskeyMfaMethod: Sendable {
    /// Date when the MFA method was verified
    public let verifiedAt: Date
}

internal extension MfaMethodResponse {
    func toMfaMethodOrNull() -> MfaMethod? {
        switch self {
        case .sms(let smsMfaMethodResponse):
            .sms(smsMfaMethodResponse.toSmsMfaMethod())
        case .totp(let totpMfaMethodResponse):
            .totp(totpMfaMethodResponse.toTotpMfaMethod())
        case .passkey(let passkeyMfaMethodResponse):
            .passkey(passkeyMfaMethodResponse.toPasskeyMfaMethod())
        case .unknown:
            nil
        }
    }
}

internal extension SmsMfaMethodResponse {
    func toSmsMfaMethod() -> SmsMfaMethod {
        return SmsMfaMethod(verifiedAt: verifiedAt.date)
    }
}

internal extension TotpMfaMethodResponse {
    func toTotpMfaMethod() -> TotpMfaMethod {
        return TotpMfaMethod(verifiedAt: verifiedAt.date)
    }
}

internal extension PasskeyMfaMethodResponse {
    func toPasskeyMfaMethod() -> PasskeyMfaMethod {
        return PasskeyMfaMethod(verifiedAt: verifiedAt.date)
    }
}
