import Foundation

/// The parameters for building a Sign-In with Solana (SIWS) message
public struct SiwsMessageParams: Sendable {
    /// The domain that is requesting the signing. Its value MUST be an *[RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) authority*.
    public let domain: String

    /// An *[RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) URI* referring to the resource that is the subject of the signing (as in the subject of a claim).
    public let uri: String

    /// Solana address performing the sign-in. The address is case-sensitive.
    public let address: String

    public init(domain: String, uri: String, address: String) {
        self.domain = domain
        self.uri = uri
        self.address = address
    }
}
