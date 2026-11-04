import Foundation
import AuthenticationServices
internal import FactoryKit

extension PrivyContainer {
    internal var loginWithOAuth: Factory<LoginWithOAuth> {
        self { @MainActor in LoginWithOAuthImpl() }.shared
    }
}

private final class LoginWithOAuthImpl: LoginWithOAuth {
    private let authManager: AuthManager = resolve(\PrivyContainer.authManager)
    private let pkceHelper: PKCEHelper = resolve(\PrivyContainer.pkceHelper)
    private let defaultASContextProvider = resolve(\PrivyContainer.defaultASPresentationAnchorProvider)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    // Main Actor because this requires us to handle UI APIs
    @MainActor
    func login(with provider: OAuthProvider, appUrlScheme: String?) async throws -> PrivyUser {
        // Run the shared OAuth flow (no auth token for login)
        let result = try await performOAuthFlow(
            provider: provider,
            appUrlScheme: appUrlScheme,
            authToken: nil
        )

        // Authenticate with the retrieved codes
        return try await self.handleAuthenticationResponse(
            stateCode: result.stateCode,
            oauthCredentials: result.oauthCredentials,
            provider: provider,
            codeVerifier: result.codeVerifier
        )
    }

    // Main Actor because this requires us to handle UI APIs
    @MainActor
    func link(with provider: OAuthProvider, appUrlScheme: String?) async throws -> PrivyUser {
        // Ensure that a user is authenticated and get their access token
        let authState = try authManager.ensureAuthenticated()

        // Run the shared OAuth flow (provide auth token for link)
        let result = try await performOAuthFlow(
            provider: provider,
            appUrlScheme: appUrlScheme,
            authToken: authState.authToken
        )

        // Ensure privy_oauth_state is == cached state code
        guard result.oauthCredentials.oauthState == result.stateCode else {
            throw LoginWithOAuthError.authenticationError("Unexpected auth flow. This may be a phishing attempt.")
        }

        return try await authManager.linkAccount(
            with: .oauth(
                provider: provider,
                authorizationCode: result.oauthCredentials.authorizationCode,
                codeVerifier: result.codeVerifier,
                stateCode: result.stateCode
            )
        )
    }

    func unlink(with provider: OAuthProvider, subject: String) async throws -> PrivyUser {
        logger.debug("Attempting to unlink an OAuth account from the user")

        let _ = try authManager.ensureAuthenticated()

        return try await authManager.unlinkAccount(with: .oauth(provider: provider, subject: subject))
    }

    // Main Actor because this requires us to handle UI APIs
    @MainActor
    func transferAccount(nonce: String, with provider: OAuthProvider, appUrlScheme: String?) async throws -> PrivyUser {
        // Ensure that a user is authenticated and get their access token
        let authState = try authManager.ensureAuthenticated()

        // Run the shared OAuth flow, providing the auth token since transfer requires an authenticated user
        let result = try await performOAuthFlow(
            provider: provider,
            appUrlScheme: appUrlScheme,
            authToken: authState.authToken
        )

        // Ensure privy_oauth_state is == cached state code
        guard result.oauthCredentials.oauthState == result.stateCode else {
            throw LoginWithOAuthError.authenticationError("Unexpected auth flow. This may be a phishing attempt.")
        }

        logger.debug("OAuth redirect validated, completing account transfer")

        do {
            return try await authManager.transferAccount(
                with: .oauth(
                    provider: provider,
                    authorizationCode: result.oauthCredentials.authorizationCode,
                    codeVerifier: result.codeVerifier,
                    stateCode: result.stateCode,
                    nonce: nonce
                )
            )
        } catch let privyError as PrivyError {
            throw privyError
        } catch {
            logger.error("Error transferring OAuth account", error: error)
            throw PrivyError(.authenticationFailure(reason: .failureDuringAuthentication(error: error)))
        }
    }

    // MARK: - Shared OAuth flow

    @MainActor
    private func performOAuthFlow(
        provider: OAuthProvider,
        appUrlScheme: String?,
        authToken: String?
    ) async throws -> (oauthCredentials: OAuthCredentials, codeVerifier: String, stateCode: String) {
        // Determine app url scheme to use for oauth login/link, or throw error if invalid
        let urlScheme = try self.resolveAppUrlScheme(providedUrlScheme: appUrlScheme)

        // Generate code verifier, challenge, and state code
        let codeVerifier = pkceHelper.generateCodeVerifier()
        let codeChallenge = pkceHelper.deriveCodeChallenge(from: codeVerifier)
        let stateCode = pkceHelper.generateStateCode()

        // Create a URI from scheme by adding the "://" suffix
        let redirectUri = urlScheme.addSchemeSeparatorIfNeeded()

        // Hit /init endpoint, retrieve oauth url
        let authManager = resolve(\PrivyContainer.authManager)
        let oAuthInitResponse = try await authManager.generateOAuthUrl(
            oAuthInitRequest: OAuthInitRequest(
                provider: provider,
                redirectUri: redirectUri,
                codeChallenge: codeChallenge,
                stateCode: stateCode,
                authToken: authToken
            )
        )

        guard let oAuthProviderUrl = URL(string: oAuthInitResponse.url) else {
            throw LoginWithOAuthError.authenticationError("Invalid oAuth provider URL")
        }

        // Start the appropriate authentication flow
        let oauthCredentials: OAuthCredentials = if provider == .apple {
            try await startNativeAppleIDAuthentication(stateCode: stateCode)
        } else {
            try await startAuthentication(
                authURL: oAuthProviderUrl,
                callbackURLScheme: urlScheme,
                presentationContextProvider: PresentationContextProvider(defaultAsContextProvider: defaultASContextProvider)
            )
        }

        return (oauthCredentials, codeVerifier, stateCode)
    }

    private func handleAuthenticationResponse(
        stateCode: String,
        oauthCredentials: OAuthCredentials,
        provider: OAuthProvider,
        codeVerifier: String
    ) async throws -> PrivyUser {
        // Ensure privy_oauth_state is == cached state code
        guard oauthCredentials.oauthState == stateCode else {
            throw LoginWithOAuthError.authenticationError("Unexpected auth flow. This may be a phishing attempt.")
        }

        // Authenticate with the retrieved codes
        return try await authenticate(
            provider: provider,
            authorizationCode: oauthCredentials.authorizationCode,
            codeVerifier: codeVerifier,
            stateCode: oauthCredentials.oauthState
        )
    }

    // Function to start the authentication session and return the result asynchronously
    @MainActor
    private func startAuthentication(
        authURL: URL,
        callbackURLScheme: String,
        presentationContextProvider: PresentationContextProvider
    ) async throws -> OAuthCredentials {
        // Create a continuation to bridge between the completion handler and async/await
        let authSessionCallbackURL = try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme,
                completionHandler: { callbackURL, error in
                    if let callback = callbackURL {
                        // Received callback url from auth session, pass to continuation
                        continuation.resume(returning: callback)
                    } else {
                        // Error received during auth session, propogate error though
                        let err = error ?? LoginWithOAuthError.authenticationError("Failed to generate callback URL")
                        continuation.resume(throwing: err)
                    }
                }
            )

            // Set the presentation context provider
            authSession.presentationContextProvider = presentationContextProvider

            // Start the authentication session
            authSession.start()
        }

        // Extract authorization_code, code_verifier, state_code from redirect URL params
        guard let queryItems = URLComponents(string: authSessionCallbackURL.absoluteString)?.queryItems,
              let privyOAuthState = queryItems.first(where: { $0.name == Constants.oauthStateCode })?.value,
              let privyOAuthAuthorizationCode = queryItems.first(where: { $0.name == Constants.oauthAuthorizationCode })?.value else {
            throw LoginWithOAuthError.authenticationError("Malformed callback URL does not contain expected params")
        }

        return OAuthCredentials(authorizationCode: privyOAuthAuthorizationCode, oauthState: privyOAuthState)
    }

    @MainActor
    private func startNativeAppleIDAuthentication(stateCode: String) async throws -> OAuthCredentials {
        let nativeAppleIDHelper: NativeAppleIDHelper = resolve(\PrivyContainer.nativeAppleIDHelper)
        let credential = try await nativeAppleIDHelper.requestAppleIDCredentials(state: stateCode)

        guard let privyOAuthState = credential.state,
              let authorizationCodeData = credential.authorizationCode,
              let privyOAuthAuthorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            throw LoginWithOAuthError.authenticationError("Malformed credential returned by the Login with Apple ID flow")
        }

        return OAuthCredentials(authorizationCode: privyOAuthAuthorizationCode, oauthState: privyOAuthState)
    }

    private func authenticate(
        provider: OAuthProvider,
        authorizationCode: String,
        codeVerifier: String,
        stateCode: String
    ) async throws -> PrivyUser {
        return try await authManager.login(
            with: .oauth(
                provider: provider,
                authorizationCode: authorizationCode,
                codeVerifier: codeVerifier,
                stateCode: stateCode
            )
        )
    }

    /// If user passed in a url scheme, use it.
    /// If not, fallback to first valid URL scheme in the app's info.plist
    /// If neither are available, throws an error
    private func resolveAppUrlScheme(providedUrlScheme: String?) throws -> String {
        guard let urlScheme = providedUrlScheme ?? self.getFirstUrlSchemeFromInfoPList() else {
            throw LoginWithOAuthError.authenticationError(
                "App URL scheme must be explicitly passed in to `login` or a custom URL scheme must be set in your info.plist"
            )
        }

        return urlScheme
    }

    /// Finds the first valid URL scheme in the app's info.plist
    private func getFirstUrlSchemeFromInfoPList() -> String? {
        if let infoDictionary = Bundle.main.infoDictionary,
           let urlTypes = infoDictionary["CFBundleURLTypes"] as? [[String: Any]] {
            for urlType in urlTypes {
                if let urlSchemes = urlType["CFBundleURLSchemes"] as? [String], let urlScheme = urlSchemes.first, urlScheme != "" {
                    return urlScheme
                }
            }
        }
        return nil
    }
}

private extension LoginWithOAuthImpl {
    private enum Constants {
        static let oauthStateCode = "privy_oauth_state"
        static let oauthAuthorizationCode = "privy_oauth_code"
    }
}

private extension String {
    // Returns a new String that adds the :// suffix to a string if it doesn't already contain it
    func addSchemeSeparatorIfNeeded() -> String {
        let schemeSeparator = "://"
        if self.hasSuffix(schemeSeparator) {
            return self // Separator already present
        } else {
            return self + schemeSeparator // Add the separator
        }
    }
}

private struct OAuthCredentials {
    let authorizationCode: String
    let oauthState: String
}

@MainActor
private class PresentationContextProvider:
    NSObject, ASWebAuthenticationPresentationContextProviding {
    let defaultASContextProvider: DefaultASPresentationAnchorProvider

    init(defaultAsContextProvider: DefaultASPresentationAnchorProvider) {
        self.defaultASContextProvider = defaultAsContextProvider
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return defaultASContextProvider.provide()
    }
}
