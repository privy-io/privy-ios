import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var backendErrorInterceptor: Factory<BackendErrorInterceptor> {
        self { AccountTransferBackendErrorInterceptor() }.shared
    }
}

/// Recognizes the `account_transfer_required` backend error code and throws a typed
/// ``AccountTransferBackendError`` in its place, so callers don't have to deal with the generic `ApiError`.
private struct AccountTransferBackendErrorInterceptor: BackendErrorInterceptor {
    func intercept(code: String, responseData: Data) throws {
        guard code == AccountTransferBackendError.errorCode,
              let payload = try? JSONDecoder().decode(AccountTransferBackendErrorPayload.self, from: responseData),
              let nonce = payload.data?.nonce else {
            return
        }

        let otherUser = payload.data?.otherUser
        let account = payload.data?.account
        throw AccountTransferBackendError(
            nonce: nonce,
            embeddedWalletAddress: otherUser?.embeddedWalletAddress,
            farcasterEmbeddedAddress: otherUser?.farcasterEmbeddedAddress,
            displayName: account?.displayName,
            oAuthUserInfo: otherUser?.oAuthUserInfo
        )
    }
}

private struct AccountTransferBackendErrorPayload: Decodable {
    let data: TransferErrorData?
}

internal struct TransferErrorData: Decodable {
    internal let nonce: String?
    internal let otherUser: TransferOtherUser?
    internal let account: TransferConflictingAccount?
}

internal struct TransferOtherUser: Decodable {
    internal let embeddedWalletAddress: String?
    internal let farcasterEmbeddedAddress: String?
    internal let oAuthUserInfo: [String: String?]?
}

internal struct TransferConflictingAccount: Decodable {
    internal let displayName: String?
}

/// Internal error thrown by the network layer when the backend returns `account_transfer_required`.
/// Converted to the public `PrivyError(.authenticationFailure(.accountTransferRequired))` at the auth-manager layer.
internal struct AccountTransferBackendError: Error {
    internal static let errorCode = "account_transfer_required"

    internal let nonce: String
    internal let embeddedWalletAddress: String?
    internal let farcasterEmbeddedAddress: String?
    internal let displayName: String?
    internal let oAuthUserInfo: [String: String?]?

    internal func toPrivyError() -> PrivyError {
        PrivyError(.authenticationFailure(reason: .accountTransferRequired(
            nonce: nonce,
            conflictingUser: ConflictingUserMetadata(
                embeddedWalletAddress: embeddedWalletAddress,
                farcasterEmbeddedAddress: farcasterEmbeddedAddress,
                displayName: displayName,
                oAuthUserInfo: oAuthUserInfo
            )
        )))
    }
}
