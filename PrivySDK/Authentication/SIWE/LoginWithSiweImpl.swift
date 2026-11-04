import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var loginWithSiwe: Factory<LoginWithSiwe> {
        self { LoginWithSiweImpl() }.shared
    }
}

private final class LoginWithSiweImpl: LoginWithSiwe {
    private enum Constants {
        static let siweMessageStatement = "By signing, you are proving you own this wallet and logging in. This does not initiate a transaction or cost any fees."
    }

    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    func generateMessage(params: SiweMessageParams) async throws -> String {
        do {
            logger.verbose("Generating SIWE message")
            let response = try await authManager.generateSiweMessage(walletAddress: params.walletAddress)

            return createSiweMessage(params: params, response: response)
        } catch {
            logger.error("Error generating SIWE message", error: error)
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }

    func generateSiweMessage(params: SiweMessageParams) async throws -> String {
        try await generateMessage(params: params)
    }

    func login(message: String, signature: String, params: SiweMessageParams, metadata: WalletLoginMetadata?) async throws -> PrivyUser {
        logger.verbose("Logging user in via SIWE.")
        return try await executeSiweAuth(
            message: message,
            signature: signature,
            params: params,
            metadata: metadata,
            authCall: { loginType in
                try await authManager.login(with: loginType)
            }
        )
    }

    func loginWithSiwe(message: String, signature: String, params: SiweMessageParams, metadata: WalletLoginMetadata?) async throws -> PrivyUser {
        try await login(message: message, signature: signature, params: params, metadata: metadata)
    }

    func link(message: String, signature: String, params: SiweMessageParams, metadata: WalletLoginMetadata?) async throws -> PrivyUser {
        logger.verbose("Linking SIWE")

        // ensure user is authenticated before linking
        let _ = try authManager.ensureAuthenticated()

        return try await executeSiweAuth(
            message: message,
            signature: signature,
            params: params,
            metadata: metadata,
            authCall: { loginType in
                try await authManager.linkAccount(with: loginType)
            }
        )
    }

    func linkWithSiwe(message: String, signature: String, params: SiweMessageParams, metadata: WalletLoginMetadata?) async throws -> PrivyUser {
        try await link(message: message, signature: signature, params: params, metadata: metadata)
    }

    func unlink(address: String) async throws -> PrivyUser {
        logger.debug("Attempting to unlink an EOA wallet from the user")

        let _ = try authManager.ensureAuthenticated()

        return try await authManager.unlinkAccount(with: .siwe(address: address))
    }

    func transferAccount(
        nonce: String,
        message: String,
        signature: String,
        params: SiweMessageParams,
        metadata: WalletLoginMetadata?
    ) async throws -> PrivyUser {
        logger.verbose("Transferring SIWE account")

        let _ = try authManager.ensureAuthenticated()

        do {
            let siweLoginParams = SiweLoginParams(
                message: message,
                signature: signature,
                chainId: params.chainId,
                walletAddress: params.walletAddress,
                walletClientType: metadata?.walletClientType,
                connectorType: metadata?.connectorType
            )

            let result = try await authManager.transferAccount(with: .siwe(params: siweLoginParams, nonce: nonce))

            logger.verbose("Transferred SIWE account successfully")

            return result
        } catch let privyError as PrivyError {
            throw privyError
        } catch {
            logger.error("Error transferring SIWE account", error: error)
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }

    private func executeSiweAuth<T: Sendable>(
        message: String,
        signature: String,
        params: SiweMessageParams,
        metadata: WalletLoginMetadata?,
        authCall: (LoginType) async throws -> T
    ) async throws -> T {
        let chainId = params.chainId

        do {
            let siweLoginType = LoginType.siwe(
                params: SiweLoginParams(
                    message: message,
                    signature: signature,
                    chainId: chainId,
                    walletAddress: params.walletAddress,
                    walletClientType: metadata?.walletClientType,
                    connectorType: metadata?.connectorType
                )
            )

            let result = try await authCall(siweLoginType)

            logger.verbose("Authenticated with SIWE successfully")

            return result
        } catch let privyError as PrivyError {
            throw privyError
        } catch {
            logger.error("Error authenticating with SIWE", error: error)
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }

    private func createSiweMessage(params: SiweMessageParams, response: GenerateSiweMessageResponse) -> String {
        return """
        \(params.appDomain) wants you to sign in with your Ethereum account:
        \(params.walletAddress)

        \(Constants.siweMessageStatement)

        URI: \(params.appUri)
        Version: 1
        Chain ID: \(params.chainId)
        Nonce: \(response.nonce)
        Issued At: \(Date().toISO8601())
        Resources:
        - https://privy.io
        """
    }
}
