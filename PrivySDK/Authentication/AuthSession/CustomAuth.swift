import Foundation

/// Account created with a custom auth provider
public struct CustomAuth: Sendable {
    /// The user ID given by the custom auth provider
    public let userId: String
    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension CustomAuthAccountResponse {
    func toCustomAuth() -> CustomAuth {
        return CustomAuth(
            userId: customUserId,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
