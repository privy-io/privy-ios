import Foundation
internal import FactoryKit

internal protocol MfaTokenRepository: Sendable {
    func save(mfaToken: String) async throws

    func retrieve() async -> String?

    func delete() async
}

extension PrivyContainer {
    internal var mfaTokenRepository: Factory<MfaTokenRepository> {
        self { MfaTokenRepositoryImpl() }.shared
    }
}

private final class MfaTokenRepositoryImpl: MfaTokenRepository {
    private enum Constants {
        static let mfaTokenPersistenceKey = "mfaTokenV1"
    }

    private let storageAdapter: StorageAdapter = resolve(\PrivyContainer.storageAdapter)
    private let webViewHandler: WebviewHandler = resolve(\PrivyContainer.webViewHandler)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    func save(mfaToken: String) async throws {
        guard let data = mfaToken.data(using: .utf8) else {
            // This should never happen given a well formed String we get from the API.
            // However, it is technically possible, so we throw an error in this case.
            throw EncodingError.invalidValue(mfaToken, .init(codingPath: [], debugDescription: "Failed to encode MFA token as UTF-8"))
        }

        // Save to storage first
        try await storageAdapter.createOrUpdate(key: Constants.mfaTokenPersistenceKey, data: data)
    }

    func retrieve() async -> String? {
        guard let data = await storageAdapter.get(key: Constants.mfaTokenPersistenceKey) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete() async {
        // Not a property to avoid cycles
        let authManager: AuthManager = PrivyContainer.shared.authManager.resolve()

        // Delete from storage
        await storageAdapter.delete(key: Constants.mfaTokenPersistenceKey)

        // Only clear from iframe if the user has on-device (non-TEE) wallets.
        // TEE wallet users handle MFA tokens natively via request headers.
        do {
            let auth = try authManager.ensureAuthenticated()

            guard let wallet = try? auth.user.linkedAccounts.getPrimaryWalletForEntropyInfo(),
                  !wallet.isTEEWallet
            else {
                return
            }

            let data = ClearMfaRequestData(userId: auth.user.id)
            _ = try await webViewHandler.clearMfa(data: data)
        } catch {
            logger.verbose("Failed to clear MFA token from iframe: \(error)")
            // Don't throw - storage cleared, iframe is optional
        }
    }
}
