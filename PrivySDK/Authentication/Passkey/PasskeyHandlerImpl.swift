import Foundation
import AuthenticationServices
internal import FactoryKit

extension PrivyContainer {
    internal var passkeyHandler: Factory<PasskeyHandler> {
        self { PasskeyHandlerImpl() }
    }
}

@MainActor
private class PasskeyHandlerImpl: PasskeyHandler {
    private lazy var presentationContextProvider: PresentationContextProvider = {
        PresentationContextProvider(defaultAsContextProvider: resolve(\PrivyContainer.defaultASPresentationAnchorProvider))
    }()

    private lazy var registrationDelegate = {
        PasskeyASAuthorizationControllerDelegate()
    }()

    // delegate must be initialized here to prevent being garbage collected
    private lazy var authenticationDelegate = {
        PasskeyASAuthorizationControllerDelegate()
    }()

    func createCredential(
        registrationOptions: PasskeyRegistrationApiOptions,
        overrideDisplayName: String?
    ) async throws -> PasskeyRegistrationCredential {
        // Convert registration options to ASAuthorization request
        guard let challengeData = Data(base64URLEncoded: registrationOptions.challenge) else {
            throw PrivyError(.authenticationFailure(reason: .passkeyCreationFailed("Invalid challenge data")))
        }

        // User ID can be either base64URL-encoded or plain string, try both
        let userIdData: Data
        if let decoded = Data(base64URLEncoded: registrationOptions.user.id) {
            userIdData = decoded
        } else if let utf8Data = registrationOptions.user.id.data(using: .utf8) {
            userIdData = utf8Data
        } else {
            throw PrivyError(.authenticationFailure(reason: .passkeyCreationFailed("Invalid user ID")))
        }

        // Create the registration request
        let registrationProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: registrationOptions.rp.id)
        let registrationRequest = registrationProvider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: overrideDisplayName ?? registrationOptions.user.name,
            userID: userIdData
        )

        // Create a continuation to bridge between the delegate and async/await
        let authorization = try await withCheckedThrowingContinuation { continuation in
            registrationDelegate.completion = { result in
                self.registrationDelegate.completion = nil
                continuation.resume(with: result)
            }

            let authorizationController = ASAuthorizationController(authorizationRequests: [registrationRequest])
            authorizationController.presentationContextProvider = presentationContextProvider
            authorizationController.delegate = registrationDelegate
            authorizationController.performRequests()
        }

        // Extract the credential from the authorization
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw PrivyError(.authenticationFailure(reason: .passkeyCreationFailed("No credential returned")))
        }

        // Convert ASAuthorizationPlatformPublicKeyCredentialRegistration to PasskeyRegistrationResponse
        return try convertRegistrationCredential(credential)
    }

    func getCredential(authenticationOptions: PasskeyAuthenticationApiOptions) async throws -> PasskeyAuthenticationCredential {
        // Convert authentication options to ASAuthorization request
        guard let challengeData = Data(base64URLEncoded: authenticationOptions.challenge) else {
            throw PrivyError(.authenticationFailure(reason: .passkeyAuthenticationFailed("Invalid challenge data")))
        }

        // Create the assertion request
        let assertionProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: authenticationOptions.rpId)
        let assertionRequest = assertionProvider.createCredentialAssertionRequest(challenge: challengeData)

        // Create a continuation to bridge between the delegate and async/await
        let authorization = try await withCheckedThrowingContinuation { continuation in
            authenticationDelegate.completion = { result in
                self.authenticationDelegate.completion = nil
                continuation.resume(with: result)
            }

            let authorizationController = ASAuthorizationController(authorizationRequests: [assertionRequest])
            authorizationController.presentationContextProvider = presentationContextProvider
            authorizationController.delegate = authenticationDelegate
            authorizationController.performRequests()
        }

        // Extract the credential from the authorization
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PrivyError(.authenticationFailure(reason: .passkeyAuthenticationFailed("No credential returned")))
        }

        // Convert ASAuthorizationPlatformPublicKeyCredentialAssertion to PasskeyAuthenticationResponse
        return try convertAssertionCredential(credential)
    }

    private func convertRegistrationCredential(_ credential: ASAuthorizationPlatformPublicKeyCredentialRegistration) throws -> PasskeyRegistrationCredential {
        // Per WebAuthn spec: fields should both be base64URL encoded
        let credentialId = credential.credentialID.base64UrlEncodedString()
        let rawId = credential.credentialID.base64UrlEncodedString()
        let clientDataJSON = credential.rawClientDataJSON.base64UrlEncodedString()
        let attestationObject = credential.rawAttestationObject?.base64UrlEncodedString() ?? ""

        return PasskeyRegistrationCredential(
            type: "public-key",
            id: credentialId,
            rawId: rawId,
            response: AuthenticatorAttestationResponse(
                clientDataJSON: clientDataJSON,
                attestationObject: attestationObject,
                transports: nil,
                publicKeyAlgorithm: nil,
                publicKey: nil,
                authenticatorData: nil
            ),
            authenticatorAttachment: "platform",
            clientExtensionResults: [:]
        )
    }

    private func convertAssertionCredential(_ credential: ASAuthorizationPlatformPublicKeyCredentialAssertion) throws -> PasskeyAuthenticationCredential {
        // Per WebAuthn spec: id and rawId should both be base64URL encoded
        let credentialId = credential.credentialID.base64UrlEncodedString()
        let rawId = credential.credentialID.base64UrlEncodedString()
        let clientDataJSON = credential.rawClientDataJSON.base64UrlEncodedString()
        let authenticatorData = credential.rawAuthenticatorData.base64UrlEncodedString()
        let signature = credential.signature.base64UrlEncodedString()
        let userHandle = credential.userID.base64UrlEncodedString()

        return PasskeyAuthenticationCredential(
            type: "public-key",
            id: credentialId,
            rawId: rawId,
            response: AuthenticatorAssertionResponse(
                clientDataJSON: clientDataJSON,
                authenticatorData: authenticatorData,
                signature: signature,
                userHandle: userHandle
            ),
            authenticatorAttachment: "platform",
            clientExtensionResults: [:]
        )
    }
}

// MARK: - Passkey Delegate

private class PasskeyASAuthorizationControllerDelegate: NSObject, ASAuthorizationControllerDelegate {
    internal var completion: ((Result<ASAuthorization, any Error>) -> ())?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        self.completion?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        // Map ASAuthorizationError to PrivyError
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                self.completion?(.failure(PrivyError(.authenticationFailure(reason: .passkeyUserCancelled))))
            case .failed:
                self.completion?(.failure(PrivyError(.authenticationFailure(reason: .passkeyAuthenticationFailed("Passkey operation failed")))))
            case .notHandled:
                self.completion?(.failure(PrivyError(.authenticationFailure(reason: .passkeyAuthenticationFailed("Passkey operation not handled")))))
            default:
                self.completion?(.failure(PrivyError(.authenticationFailure(reason: .passkeyAuthenticationFailed(error.localizedDescription)))))
            }
        } else {
            self.completion?(.failure(error))
        }
    }
}

// MARK: - Presentation Context Provider

private class PresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    internal let defaultAsContextProvider: DefaultASPresentationAnchorProvider

    init(defaultAsContextProvider: DefaultASPresentationAnchorProvider) {
        self.defaultAsContextProvider = defaultAsContextProvider
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return defaultAsContextProvider.provide()
    }
}
