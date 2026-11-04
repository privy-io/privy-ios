import Foundation

// MARK: - SMS MFA Models

/// Request body for `/api/v1/mfa/passwordless_sms/init` when enrolling
internal struct SmsMfaInitEnrollRequest: Encodable {
    internal let action = "enroll"
    internal let phoneNumber: String
}

/// Request body for `/api/v1/mfa/passwordless_sms/init` when verifying
internal struct SmsMfaInitVerifyRequest: Encodable {
    internal let action = "verify"
}

/// Request body for `/api/v1/mfa/passwordless_sms/enroll`
internal struct SmsMfaEnrollRequest: Encodable {
    internal let code: String
    internal let phoneNumber: String
}

/// Request body for `/api/v1/mfa/passwordless_sms/verify`
internal struct SmsMfaVerifyRequest: Encodable {
    internal let code: String
}
