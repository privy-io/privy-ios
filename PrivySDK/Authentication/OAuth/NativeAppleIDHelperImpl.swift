import Foundation
import AuthenticationServices
internal import FactoryKit

extension PrivyContainer {
    internal var nativeAppleIDHelper: Factory<NativeAppleIDHelper> {
        self { NativeAppleIDHelperImpl() }.shared
    }
}

@MainActor
private class NativeAppleIDHelperImpl: NativeAppleIDHelper {
    private let appleIDProvider = ASAuthorizationAppleIDProvider()

    private lazy var presentationContextProvider: PresentationContextProvider = {
        PresentationContextProvider(defaultAsContextProvider: resolve(\PrivyContainer.defaultASPresentationAnchorProvider))
    }()

    private lazy var loginWithAppleDelegate = {
        LoginWithAppleASAuthorizationControllerDelegate()
    }()

    func requestAppleIDCredentials(state: String) async throws -> ASAuthorizationAppleIDCredential {
        let request = appleIDProvider.createRequest()
        request.requestedOperation = .operationLogin
        request.requestedScopes = [.fullName, .email]
        request.state = state

        // Create a continuation to bridge between the delegate and async/await
        let authorization = try await withCheckedThrowingContinuation { continuation in
            loginWithAppleDelegate.completion = { result in
                self.loginWithAppleDelegate.completion = nil
                continuation.resume(with: result)
            }

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.presentationContextProvider = presentationContextProvider
            authorizationController.delegate = loginWithAppleDelegate
            authorizationController.performRequests()
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw LoginWithOAuthError.authenticationError("No credential returned by the Login with Apple ID flow")
        }

        return credential
    }
}

private class LoginWithAppleASAuthorizationControllerDelegate: NSObject, ASAuthorizationControllerDelegate {
    var completion: ((Result<ASAuthorization, any Error>) -> ())?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        self.completion?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        self.completion?(.failure(error))
    }
}

private class PresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    let defaultAsContextProvider: DefaultASPresentationAnchorProvider

    init(defaultAsContextProvider: DefaultASPresentationAnchorProvider) {
        self.defaultAsContextProvider = defaultAsContextProvider
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return defaultAsContextProvider.provide()
    }
}
