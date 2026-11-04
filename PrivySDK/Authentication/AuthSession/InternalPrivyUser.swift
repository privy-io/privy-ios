import Foundation

internal struct InternalPrivyUser: Sendable {
    internal let id: String
    internal let createdAt: Date
    internal let linkedAccounts: [LinkedAccount]
    internal let mfaMethods: [MfaMethod]
}

internal extension UserResponse {
    func toPrivyUser() -> InternalPrivyUser {
        return InternalPrivyUser(
            id: id,
            createdAt: createdAt.date,
            linkedAccounts: linkedAccounts.compactMap { $0.toLinkedAccountOrNull() },
            mfaMethods: mfaMethods.compactMap { $0.toMfaMethodOrNull() }
        )
    }
}
