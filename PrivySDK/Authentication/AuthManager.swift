import Foundation

internal protocol AuthManager: Sendable {
    /**
     * Sends an OTP to a user
     *
     * - Parameters:
     *  - otpRequestType: Specifies where to send OTP to user
     * - Throws: if sending OTP is not successful
     */
    func sendOtp(to otpRequestType: OtpRequestType) async throws

    func login(with loginType: LoginType) async throws -> PrivyUser

    func loginWithSiws(address: String?, signing message: String, with signature: String, metadata: WalletLoginMetadata?) async throws -> PrivyUser

    func linkAccount(with loginType: LoginType) async throws -> PrivyUser
    func transferAccount(with transferType: TransferType) async throws -> PrivyUser

    func unlinkAccount(with unlinkType: UnlinkType) async throws -> PrivyUser

    func linkWithSiws(address: String?, signing message: String, with signature: String, metadata: WalletLoginMetadata?) async throws -> PrivyUser

    func unlinkSiwsWallet(address: String) async throws -> PrivyUser

    func restoreSession() async

    func refreshSession() async throws -> InternalAuthSession

    func refreshUser() async throws -> InternalPrivyUser

    func refreshSessionIfNeeded() async throws -> InternalAuthSession

    func logout() async

    func generateSiweMessage(walletAddress: String) async throws -> GenerateSiweMessageResponse

    func generateSiwsMessage(for address: String) async throws -> SiwsInitResponseBody

    func generateOAuthUrl(oAuthInitRequest: OAuthInitRequest) async throws -> OAuthInitResponse

    func updateEmail(to email: String, with code: String) async throws

    func updatePhoneNumber(to phoneNumber: String, with code: String) async throws

    /// Returns the session of the currently authenticated user.
    /// - Throws: `PrivyError` if no user is authenticated.
    nonisolated func ensureAuthenticated() throws -> InternalAuthSession

    // Passkeys
    func generatePasskeyRegistrationOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions

    func generatePasskeyAuthenticationOptions(relyingParty: URL) async throws -> PasskeyAuthenticationApiOptions

    func generatePasskeyLinkOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions

    func linkPasskey(credential: PasskeyRegistrationCredential, relyingParty: String) async throws -> PrivyUser

    func unlinkPasskey(credentialId: String, removeAsMfa: Bool) async throws -> PrivyUser
}
