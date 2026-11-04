import Foundation

///
/// This struct represents the payload structure that will be signed using the authenticated user's signer key.
///
/// Example usage: Signing an Ethereum "personal_sign" rpc
/// ```swift
/// struct SignRequest: Encodable {
///     let method: String
///     let params: SignParams
/// }
///
/// struct SignParams: Encodable {
///     let message: String
///     let encoding: String
/// }
///
/// let rpcRequest = SignRequest(
///     method: "personal_sign",
///     params: SignParams(message: "Hello, world!", encoding: "utf-8")
/// )
///
/// let payload = WalletApiPayload(
///     version: 1,
///     url: "https://auth.privy.io/api/v1/wallets/{wallet_id}/rpc",
///     method: "POST",
///     headers: ["privy-app-id": "clxyz123"],
///     body: rpcRequest
/// )
/// let signature = try await privyUser.generateAuthorizationSignature(payload: payload)
/// ```
public struct WalletApiPayload<T: Encodable>: Encodable {
    /// The payload version. Currently, only version `1` is supported.
    public let version: Int

    /// The full URL of the API endpoint, including protocol and domain. Should not include a trailing slash.
    ///
    /// Example: `"https://auth.privy.io/api/v1/wallets/{wallet_id}/rpc"`
    public let url: String

    /// The HTTP method for the request (e.g., `"GET"`, `"POST"`, `"PUT"`, `"DELETE"`).
    public let method: String

    ///
    /// Privy-specific headers, e.g. those that are prefixed with 'privy-'. This should not include any other headers,
    /// such as authentication headers, content-type, or trace headers.
    ///
    /// Privy app ID header is always required.
    ///
    /// Example: `["privy-app-id": "clxyz123"]`
    public let headers: [String: String]

    /// The request body to be serialized and included in the signature.
    public let body: T

    public init(version: Int, url: String, method: String, headers: [String: String], body: T) {
        self.version = version
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

extension WalletApiPayload {
    /// Cryptographically safe predictable canocalization of JSON as defined by RFC8785
    internal func canonicalize() throws -> Data {
        return try JsonCanonicalizer().encode(self)
    }
}
