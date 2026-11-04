import CryptoKit
import Foundation
internal import FactoryKit

internal final class NativeUserSigner: UserSigner {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let userSignerRepository: UserSignerRepository = resolve(\PrivyContainer.userSignerRepository)
    private let ongoingMfaManager: PrivyOngoingMFAManager = resolve(\PrivyContainer.ongoingMfaManager)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    internal func signature(for message: Data) async throws -> String {
        let _ = try authManager.ensureAuthenticated()
        let session = try await authManager.refreshSessionIfNeeded()

        return try await ongoingMfaManager.withMfaHandling { mfaToken in
            self.logger.verbose("Retrieving user signer key for native signing")
            let userSignerKey = try await self.userSignerRepository.getUserSigner(
                authToken: session.authToken,
                mfaToken: mfaToken
            )

            guard let keyData = Data(base64Encoded: userSignerKey.privateKeyBase64) else {
                self.logger.error("Failed to decode user signer key from base64", error: nil)
                throw PrivyError(.embeddedWalletFailure(reason: .signerError(message: "Failed to decode user signer key from base64")))
            }

            let privateKey = try P256.Signing.PrivateKey(derRepresentation: keyData)
            let ecdsaSignature = try privateKey.signature(for: message)
            let base64Signature = ecdsaSignature.derRepresentation.base64EncodedString()

            self.logger.verbose("Native signing succeeded")
            return base64Signature
        }
    }
}
