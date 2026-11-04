import Foundation
@testable import PrivySDK

/// In-memory `PasskeyHandler` test double. Stands in for the platform's passkey UI so tests can
/// script credential creation/retrieval and assert on what the SDK asked for.
internal final class TestPasskeyHandler: PasskeyHandler, @unchecked Sendable {
    internal var createCredentialResult: Result<PasskeyRegistrationCredential, Error> = .success(.test())
    internal private(set) var createCredentialRequests: [(options: PasskeyRegistrationApiOptions, overrideDisplayName: String?)] = []

    internal var getCredentialResult: Result<PasskeyAuthenticationCredential, Error> = .success(.test())
    internal private(set) var getCredentialRequests: [PasskeyAuthenticationApiOptions] = []

    internal func createCredential(
        registrationOptions: PasskeyRegistrationApiOptions,
        overrideDisplayName: String?
    ) async throws -> PasskeyRegistrationCredential {
        createCredentialRequests.append((registrationOptions, overrideDisplayName))
        return try createCredentialResult.get()
    }

    internal func getCredential(authenticationOptions: PasskeyAuthenticationApiOptions) async throws -> PasskeyAuthenticationCredential {
        getCredentialRequests.append(authenticationOptions)
        return try getCredentialResult.get()
    }
}
