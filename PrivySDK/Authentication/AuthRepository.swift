import Foundation

// No state management, and all methods are async await, so safely can mark as Sendable
internal protocol AuthRepository: Sendable {
    /**
     * Sends an OTP to a user
     *
     * - Parameters:
     *  - otpRequestType: Specifies where to send OTP to user
     * - Throws: if sending OTP is not successful
     */
    func sendOtp(to otpRequestType: OtpRequestType) async throws

    func authenticate(with loginType: LoginType) async throws -> AuthResponse
    func siwsAuthenticate(_ requestBody: SiwsAuthenticateRequestBody) async throws -> AuthResponse
    func link(with loginType: LoginType, authToken: String) async throws -> UserResponse
    func transfer(with transferType: TransferType, authToken: String) async throws -> UserResponse
    func unlink(with unlinkType: UnlinkType, authToken: String) async throws -> UserResponse
    func siwsLink(_ requestBody: SiwsLinkRequestBody, authToken: String) async throws -> UserResponse
    func siwsUnlink(_ requestBody: SiwsUnlinkRequestBody, authToken: String) async throws -> UserResponse
    func refreshSession(token: String, refreshToken: String) async throws -> AuthResponse
    func refreshUser(token: String) async throws -> RefreshUserResponse
    func logoutSession(authToken: String) async throws
    func generateSiweMessage(walletAddress: String) async throws -> GenerateSiweMessageResponse
    func siwsInit(_ requestBody: SiwsInitRequestBody) async throws -> SiwsInitResponseBody
    func generateOAuthUrl(oAuthInitRequest: OAuthInitRequest) async throws -> OAuthInitResponse
    func updateEmail(from oldAddress: String, to newAddress: String, with code: String, authToken: String) async throws -> UserResponse
    func updatePhoneNumber(from oldPhoneNumber: String, to newPhoneNumber: String, with code: String, authToken: String) async throws -> UserResponse

    // Passkey flows
    func generatePasskeyRegistrationOptions(relyingParty: URL) async throws -> PasskeyRegistrationApiOptions

    func generatePasskeyAuthenticationOptions(relyingParty: URL) async throws -> PasskeyAuthenticationApiOptions

    func generatePasskeyLinkOptions(relyingParty: URL, authToken: String) async throws -> PasskeyRegistrationApiOptions

    func linkPasskey(credential: PasskeyRegistrationCredential, relyingParty: String, authToken: String) async throws -> UserResponse

    func unlinkPasskey(credentialId: String, removeAsMfa: Bool, authToken: String, mfaToken: String?) async throws -> UserResponse
}
