import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var userSigner: Factory<UserSigner> {
        self { NativeUserSigner() }.shared
    }
}

internal protocol UserSigner: Sendable {
    /// Signs a byte sequence with the user's signer key.
    ///
    /// - Returns: The base64-encoded signature of the message
    ///
    /// - Throws: An error if authenticating the user in is unsuccessful
    func signature(for message: Data) async throws -> String
}

internal extension UserSigner {
    /// Canonicalizes a wallet api payload byte sequence, and signs it with the user's signer key.
    ///
    /// - Returns: The base64-encoded signature of the message
    ///
    /// - Throws: An error if authenticating the user in is unsuccessful
    ///
    func signature<T: Encodable>(for payload: WalletApiPayload<T>) async throws -> String {
        let message = try payload.canonicalize()
        return try await self.signature(for: message)
    }
}

private final class IframeBackedUserSigner: UserSigner {
    private let handler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)

    internal func signature(for message: Data) async throws -> String {
        let _ = try authManager.ensureAuthenticated()

        let session = try await authManager.refreshSessionIfNeeded()
        let accessToken = session.authToken
        let data = UserSignerSignRequestData(accessToken: accessToken, message: message)
        let response = try await handler.signWithUserSigner(data: data)
        return response.data.signature.base64EncodedString()
    }
}
