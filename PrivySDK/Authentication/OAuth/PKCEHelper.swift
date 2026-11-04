import Foundation

internal protocol PKCEHelper: Sendable {
    /**
     * Creates a cryptographic random string to be used as the code_verifier in PKCE.
     *
     * - Returns: a cryptographic random string to be used as a code_verifier in PKCE
     */
    func generateCodeVerifier() -> String

    /**
     * Generates a state code to be used in the OAuth flow.  State code can be a random set of characers,
     * or optionally can be used to store state information.  In either case, it is used by the client to verify
     * that it is communicating with the same server throughout the auth process.
     *
     * - Returns: a valid state code to be used in PKCE flow
     */
    func generateStateCode() -> String

    /**
     * Derive the code_challenge from the code verifier, using SHA 256.
     *
     * @param codeVerifier the code_challenge derived from the provided code verifier
     */
    func deriveCodeChallenge(from codeVerifier: String) -> String
}
