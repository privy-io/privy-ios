import Foundation

/// Account created via phone number
public struct PhoneNumberAccount: Sendable {
    /// The phone number of the account
    public let phoneNumber: String
    /// Date when the account was first verified
    public let firstVerifiedAt: Date?
    /// Latest date when the account was verified
    public let latestVerifiedAt: Date?
}

internal extension PhoneNumberAccountResponse {
    func toPhoneNumberAccount() -> PhoneNumberAccount {
        return PhoneNumberAccount(
            phoneNumber: phoneNumber,
            firstVerifiedAt: firstVerifiedAt?.date,
            latestVerifiedAt: latestVerifiedAt?.date
        )
    }
}
