import Foundation
@testable import PrivySDK

/// In-memory `AuthRepository` test double. Only the members exercised by auth-manager/session
/// tests are stubbable today; every other member fatal-errors if a test exercises it, so a missing
/// stub fails loudly instead of silently returning a placeholder.
///
/// `authenticate`/`refreshSession`/`refreshUser` and the link/unlink/transfer calls have no sensible
/// default `AuthResponse` / `RefreshUserResponse` / `UserResponse` to fall back to, so their results are optional and fatal-error when unset,
/// rather than defaulting to `.success(...)` like `sendOtp`/`logoutSession` do.
internal final class TestAuthRepository: AuthRepository, @unchecked Sendable {
    internal var sendOtpResult: Result<Void, Error> = .success(())
    internal private(set) var sendOtpRequests: [OtpRequestType] = []

    internal var authenticateResult: Result<AuthResponse, Error>?
    internal private(set) var authenticateRequests: [LoginType] = []

    internal var refreshSessionResult: Result<AuthResponse, Error>?
    internal private(set) var refreshSessionRequests: [(token: String, refreshToken: String)] = []
    /// Awaited after the request is recorded and before the result is returned, so a test can hold a
    /// refresh in flight to exercise concurrent callers.
    internal var refreshSessionGate: (@Sendable () async -> Void)?

    internal var refreshUserResult: Result<RefreshUserResponse, Error>?
    internal private(set) var refreshUserRequests: [String] = []

    internal var linkResult: Result<UserResponse, Error>?
    internal private(set) var linkRequests: [(loginType: LoginType, authToken: String)] = []

    internal var transferResult: Result<UserResponse, Error>?
    internal private(set) var transferRequests: [(transferType: TransferType, authToken: String)] = []

    internal var unlinkResult: Result<UserResponse, Error>?
    internal private(set) var unlinkRequests: [(unlinkType: UnlinkType, authToken: String)] = []

    internal var siwsLinkResult: Result<UserResponse, Error>?
    internal private(set) var siwsLinkRequests: [(body: SiwsLinkRequestBody, authToken: String)] = []

    internal var siwsUnlinkResult: Result<UserResponse, Error>?
    internal private(set) var siwsUnlinkRequests: [(body: SiwsUnlinkRequestBody, authToken: String)] = []

    internal var linkPasskeyResult: Result<UserResponse, Error>?
    internal private(set) var linkPasskeyRequests: [(credential: PasskeyRegistrationCredential, relyingParty: String, authToken: String)] = []

    internal var unlinkPasskeyResult: Result<UserResponse, Error>?
    internal private(set) var unlinkPasskeyRequests: [(credentialId: String, removeAsMfa: Bool, authToken: String, mfaToken: String?)] = []

    internal var logoutSessionResult: Result<Void, Error> = .success(())
    internal private(set) var logoutSessionRequests: [String] = []

    internal func sendOtp(to otpRequestType: OtpRequestType) async throws {
        sendOtpRequests.append(otpRequestType)
        try sendOtpResult.get()
    }

    internal func authenticate(with loginType: LoginType) async throws -> AuthResponse {
        authenticateRequests.append(loginType)
        guard let authenticateResult else { notStubbed("authenticate") }
        return try authenticateResult.get()
    }

    internal func siwsAuthenticate(_ requestBody: SiwsAuthenticateRequestBody) async throws -> AuthResponse {
        notStubbed("siwsAuthenticate")
    }

    internal func link(with loginType: LoginType, authToken: String) async throws -> UserResponse {
        linkRequests.append((loginType, authToken))
        guard let linkResult else { notStubbed("link") }
        return try linkResult.get()
    }

    internal func transfer(with transferType: TransferType, authToken: String) async throws -> UserResponse {
        transferRequests.append((transferType, authToken))
        guard let transferResult else { notStubbed("transfer") }
        return try transferResult.get()
    }

    internal func unlink(with unlinkType: UnlinkType, authToken: String) async throws -> UserResponse {
        unlinkRequests.append((unlinkType, authToken))
        guard let unlinkResult else { notStubbed("unlink") }
        return try unlinkResult.get()
    }

    internal func siwsLink(_ requestBody: SiwsLinkRequestBody, authToken: String) async throws -> UserResponse {
        siwsLinkRequests.append((requestBody, authToken))
        guard let siwsLinkResult else { notStubbed("siwsLink") }
        return try siwsLinkResult.get()
    }

    internal func siwsUnlink(_ requestBody: SiwsUnlinkRequestBody, authToken: String) async throws -> UserResponse {
        siwsUnlinkRequests.append((requestBody, authToken))
        guard let siwsUnlinkResult else { notStubbed("siwsUnlink") }
        return try siwsUnlinkResult.get()
    }

    internal func refreshSession(token: String, refreshToken: String) async throws -> AuthResponse {
        refreshSessionRequests.append((token, refreshToken))
        await refreshSessionGate?()
        guard let refreshSessionResult else { notStubbed("refreshSession") }
        return try refreshSessionResult.get()
    }

    internal func refreshUser(token: String) async throws -> RefreshUserResponse {
        refreshUserRequests.append(token)
        guard let refreshUserResult else { notStubbed("refreshUser") }
        return try refreshUserResult.get()
    }

    internal func logoutSession(authToken: String) async throws {
        logoutSessionRequests.append(authToken)
        try logoutSessionResult.get()
    }

    internal func generateSiweMessage(walletAddress: String) async throws -> GenerateSiweMessageResponse {
        notStubbed("generateSiweMessage")
    }

    internal func siwsInit(_ requestBody: SiwsInitRequestBody) async throws -> SiwsInitResponseBody { notStubbed("siwsInit") }

    internal func generateOAuthUrl(oAuthInitRequest: OAuthInitRequest) async throws -> OAuthInitResponse {
        notStubbed("generateOAuthUrl")
    }

    internal func updateEmail(from oldAddress: String, to newAddress: String, with code: String, authToken: String) async throws -> UserResponse {
        notStubbed("updateEmail")
    }

    internal func updatePhoneNumber(
        from oldPhoneNumber: String,
        to newPhoneNumber: String,
        with code: String,
        authToken: String
    ) async throws -> UserResponse {
        notStubbed("updatePhoneNumber")
    }

    internal func generatePasskeyRegistrationOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions {
        notStubbed("generatePasskeyRegistrationOptions")
    }

    internal func generatePasskeyAuthenticationOptions(relyingParty: URL) async throws -> PasskeyAuthenticationApiOptions {
        notStubbed("generatePasskeyAuthenticationOptions")
    }

    internal func generatePasskeyLinkOptions(relyingParty: URL, authToken: String) async throws -> PasskeyRegistrationApiOptions {
        notStubbed("generatePasskeyLinkOptions")
    }

    internal func linkPasskey(credential: PasskeyRegistrationCredential, relyingParty: String, authToken: String) async throws -> UserResponse {
        linkPasskeyRequests.append((credential, relyingParty, authToken))
        guard let linkPasskeyResult else { notStubbed("linkPasskey") }
        return try linkPasskeyResult.get()
    }

    internal func unlinkPasskey(credentialId: String, removeAsMfa: Bool, authToken: String, mfaToken: String?) async throws -> UserResponse {
        unlinkPasskeyRequests.append((credentialId, removeAsMfa, authToken, mfaToken))
        guard let unlinkPasskeyResult else { notStubbed("unlinkPasskey") }
        return try unlinkPasskeyResult.get()
    }

    private func notStubbed(_ member: String) -> Never {
        fatalError("TestAuthRepository.\(member) was called but isn't stubbed for this test.")
    }
}
