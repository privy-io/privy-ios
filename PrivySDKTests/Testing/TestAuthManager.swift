import Foundation
@testable import PrivySDK

/// In-memory `AuthManager` test double. Only the members the suites exercise are stubbable; every
/// other member fatal-errors if a test exercises it, so a missing stub fails loudly instead of
/// silently returning a placeholder.
internal final class TestAuthManager: AuthManager, @unchecked Sendable {
    internal var sendOtpResult: Result<Void, Error> = .success(())
    internal private(set) var sendOtpRequests: [OtpRequestType] = []

    internal var loginResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var loginRequests: [LoginType] = []

    internal var linkAccountResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var linkAccountRequests: [LoginType] = []

    internal var transferAccountResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var transferAccountRequests: [TransferType] = []

    internal var unlinkAccountResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var unlinkAccountRequests: [UnlinkType] = []

    internal var updatePhoneNumberResult: Result<Void, Error> = .success(())
    internal private(set) var updatePhoneNumberRequests: [(phoneNumber: String, code: String)] = []

    /// Defaults to the error the real `AuthManager` throws when no user is logged in.
    internal var ensureAuthenticatedResult: Result<InternalAuthSession, Error> = .failure(
        PrivyError(.authenticationFailure(reason: .notLoggedIn))
    )

    /// `nil` fatal-errors like an unstubbed member.
    internal var refreshSessionIfNeededResult: Result<InternalAuthSession, Error>?
    /// `nil` fatal-errors like an unstubbed member.
    internal var refreshSessionResult: Result<InternalAuthSession, Error>?
    /// `nil` fatal-errors like an unstubbed member.
    internal var refreshUserResult: Result<InternalPrivyUser, Error>?

    internal var generatePasskeyRegistrationOptionsResult: Result<PasskeyRegistrationApiOptions, Error> = .success(.test())
    internal private(set) var generatePasskeyRegistrationOptionsRequests: [URL] = []

    internal var generatePasskeyAuthenticationOptionsResult: Result<PasskeyAuthenticationApiOptions, Error> = .success(.test())
    internal private(set) var generatePasskeyAuthenticationOptionsRequests: [URL] = []

    internal var generatePasskeyLinkOptionsResult: Result<PasskeyRegistrationApiOptions, Error> = .success(.test())
    internal private(set) var generatePasskeyLinkOptionsRequests: [URL] = []

    internal var linkPasskeyResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var linkPasskeyRequests: [(credential: PasskeyRegistrationCredential, relyingParty: String)] = []

    internal var unlinkPasskeyResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var unlinkPasskeyRequests: [(credentialId: String, removeAsMfa: Bool)] = []

    internal var loginWithSiwsResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var loginWithSiwsRequests: [(address: String?, message: String, signature: String, metadata: WalletLoginMetadata?)] = []

    internal var linkWithSiwsResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var linkWithSiwsRequests: [(address: String?, message: String, signature: String, metadata: WalletLoginMetadata?)] = []

    internal var unlinkSiwsWalletResult: Result<PrivyUser, Error> = .success(TestPrivyUser())
    internal private(set) var unlinkSiwsWalletRequests: [String] = []

    internal var generateSiweMessageResult: Result<GenerateSiweMessageResponse, Error> = .success(.test())
    internal private(set) var generateSiweMessageRequests: [String] = []

    internal var generateSiwsMessageResult: Result<SiwsInitResponseBody, Error> = .success(.test())
    internal private(set) var generateSiwsMessageRequests: [String] = []

    internal var generateOAuthUrlResult: Result<OAuthInitResponse, Error> = .success(.test())
    internal private(set) var generateOAuthUrlRequests: [OAuthInitRequest] = []

    internal func sendOtp(to otpRequestType: OtpRequestType) async throws {
        sendOtpRequests.append(otpRequestType)
        try sendOtpResult.get()
    }

    internal func login(with loginType: LoginType) async throws -> PrivyUser {
        loginRequests.append(loginType)
        return try loginResult.get()
    }

    internal func loginWithSiws(address: String?, signing message: String, with signature: String, metadata: WalletLoginMetadata?) async throws -> PrivyUser {
        loginWithSiwsRequests.append((address, message, signature, metadata))
        return try loginWithSiwsResult.get()
    }

    internal func linkAccount(with loginType: LoginType) async throws -> PrivyUser {
        linkAccountRequests.append(loginType)
        return try linkAccountResult.get()
    }

    internal func transferAccount(with transferType: TransferType) async throws -> PrivyUser {
        transferAccountRequests.append(transferType)
        return try transferAccountResult.get()
    }

    internal func unlinkAccount(with unlinkType: UnlinkType) async throws -> PrivyUser {
        unlinkAccountRequests.append(unlinkType)
        return try unlinkAccountResult.get()
    }

    internal func linkWithSiws(address: String?, signing message: String, with signature: String, metadata: WalletLoginMetadata?) async throws -> PrivyUser {
        linkWithSiwsRequests.append((address, message, signature, metadata))
        return try linkWithSiwsResult.get()
    }

    internal func unlinkSiwsWallet(address: String) async throws -> PrivyUser {
        unlinkSiwsWalletRequests.append(address)
        return try unlinkSiwsWalletResult.get()
    }

    internal func restoreSession() async { notStubbed("restoreSession") }

    internal func refreshSession() async throws -> InternalAuthSession {
        guard let refreshSessionResult else { notStubbed("refreshSession") }
        return try refreshSessionResult.get()
    }

    internal func refreshUser() async throws -> InternalPrivyUser {
        guard let refreshUserResult else { notStubbed("refreshUser") }
        return try refreshUserResult.get()
    }

    internal func refreshSessionIfNeeded() async throws -> InternalAuthSession {
        guard let refreshSessionIfNeededResult else { notStubbed("refreshSessionIfNeeded") }
        return try refreshSessionIfNeededResult.get()
    }

    internal func logout() async { notStubbed("logout") }

    internal func generateSiweMessage(walletAddress: String) async throws -> GenerateSiweMessageResponse {
        generateSiweMessageRequests.append(walletAddress)
        return try generateSiweMessageResult.get()
    }

    internal func generateSiwsMessage(for address: String) async throws -> SiwsInitResponseBody {
        generateSiwsMessageRequests.append(address)
        return try generateSiwsMessageResult.get()
    }

    internal func generateOAuthUrl(oAuthInitRequest: OAuthInitRequest) async throws -> OAuthInitResponse {
        generateOAuthUrlRequests.append(oAuthInitRequest)
        return try generateOAuthUrlResult.get()
    }

    internal func updateEmail(to email: String, with code: String) async throws { notStubbed("updateEmail") }

    internal func updatePhoneNumber(to phoneNumber: String, with code: String) async throws {
        updatePhoneNumberRequests.append((phoneNumber, code))
        try updatePhoneNumberResult.get()
    }

    internal nonisolated func ensureAuthenticated() throws -> InternalAuthSession { try ensureAuthenticatedResult.get() }

    internal func generatePasskeyRegistrationOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions {
        generatePasskeyRegistrationOptionsRequests.append(relyingParty)
        return try generatePasskeyRegistrationOptionsResult.get()
    }

    internal func generatePasskeyAuthenticationOptions(relyingParty: URL) async throws -> PasskeyAuthenticationApiOptions {
        generatePasskeyAuthenticationOptionsRequests.append(relyingParty)
        return try generatePasskeyAuthenticationOptionsResult.get()
    }

    internal func generatePasskeyLinkOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions {
        generatePasskeyLinkOptionsRequests.append(relyingParty)
        return try generatePasskeyLinkOptionsResult.get()
    }

    internal func linkPasskey(credential: PasskeyRegistrationCredential, relyingParty: String) async throws -> PrivyUser {
        linkPasskeyRequests.append((credential, relyingParty))
        return try linkPasskeyResult.get()
    }

    internal func unlinkPasskey(credentialId: String, removeAsMfa: Bool) async throws -> PrivyUser {
        unlinkPasskeyRequests.append((credentialId, removeAsMfa))
        return try unlinkPasskeyResult.get()
    }

    private nonisolated func notStubbed(_ member: String) -> Never {
        fatalError("TestAuthManager.\(member) was called but isn't stubbed for this test.")
    }
}

internal extension TestAuthManager {
    /// Stubs `refreshSessionIfNeeded` with a session, and `refreshUser` with the same user holding
    /// `refreshedLinkedAccounts`.
    func stubSession(refreshedLinkedAccounts: [LinkedAccount]) {
        refreshSessionIfNeededResult = .success(.test())
        refreshUserResult = .success(InternalAuthSession.test(linkedAccounts: refreshedLinkedAccounts).user)
    }
}
