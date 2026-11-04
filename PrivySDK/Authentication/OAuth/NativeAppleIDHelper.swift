//

import Foundation
import AuthenticationServices

internal protocol NativeAppleIDHelper {
    /**
     * Prompts the native Sign in with Apple flow.
     *
     * @param state the oauth state code
     * - Returns: The user Apple ID credentials
     */
    func requestAppleIDCredentials(state: String) async throws -> ASAuthorizationAppleIDCredential
}
