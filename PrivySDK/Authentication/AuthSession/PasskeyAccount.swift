import Foundation

/// Account created via Sign in with Apple
public struct PasskeyAccount: Sendable {
    public let credentialId: String
    public let enrolledInMfa: Bool
    public let authenticatorName: String?
    public let createdWithBrowser: String?
    public let createdWithOs: String?
    public let createdWithDevice: String?
    public let publicKey: String?
    public let firstVerifiedAt: Date?
    public let latestVerifiedAt: Date?
}

internal extension PasskeyAccountResponse {
    func toPasskeyAccount() -> PasskeyAccount {
        return PasskeyAccount(
            credentialId: credentialId,
            enrolledInMfa: enrolledInMfa,
            authenticatorName: authenticatorName,
            createdWithBrowser: createdWithBrowser,
            createdWithOs: createdWithOs,
            createdWithDevice: createdWithDevice,
            publicKey: publicKey,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
