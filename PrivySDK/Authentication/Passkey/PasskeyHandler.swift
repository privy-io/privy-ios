import Foundation

internal protocol PasskeyHandler: Sendable {
    /**
     * Creates a new passkey credential (registration flow).
     *
     * - Parameter registrationOptions: The registration options from the server
     * - Returns: The created passkey registration response
     * - Throws: PrivyError if creation fails or user cancels
     */
    func createCredential(
        registrationOptions: PasskeyRegistrationApiOptions,
        overrideDisplayName: String?
    ) async throws -> PasskeyRegistrationCredential

    /**
     * Retrieves an existing passkey credential (authentication flow).
     *
     * - Parameter authenticationOptions: The authentication options from the server
     * - Returns: The passkey authentication response
     * - Throws: PrivyError if authentication fails or user cancels
     */
    func getCredential(authenticationOptions: PasskeyAuthenticationApiOptions) async throws -> PasskeyAuthenticationCredential
}
