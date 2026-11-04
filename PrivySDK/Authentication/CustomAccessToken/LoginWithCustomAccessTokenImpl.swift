import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var loginWithCustomAccessToken: Factory<LoginWithCustomAccessToken> {
        self { LoginWithCustomAccessTokenImpl() }.shared
    }
}

private final class LoginWithCustomAccessTokenImpl: LoginWithCustomAccessToken, Sendable {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let config: PrivyConfig = resolve(\PrivyContainer.config)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    init() {
        if config.customAuthConfig?.tokenProvider != nil {
            // Simply log a message if token provider was configured properly
            logger.log(level: .verbose, message: "Custom JWT token provider registered.")
        }
    }

    func loginWithCustomAccessToken() async throws -> PrivyUser {
        guard let tokenProvider = config.customAuthConfig?.tokenProvider else {
            throw PrivyError(.authenticationFailure(reason: .noCustomAuthProviderConfigured))
        }

        guard let token = try await tokenProvider() else {
            throw PrivyError(.authenticationFailure(reason: .customAuthProviderReturnedNoToken))
        }

        return try await authManager.login(with: .customAccessToken(token: token))
    }
}
