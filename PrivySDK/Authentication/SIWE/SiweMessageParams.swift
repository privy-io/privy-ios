import Foundation

/// The parameters for building a Sign-In with Ethereum (SIWE) message
public struct SiweMessageParams: Sendable {
    /// The app's domain, e.g. "my-domain.com"
    internal let appDomain: String

    /// The app's uri, e.g. "https://my-domain.com"
    internal let appUri: String

    /// EVM Chain ID, e.g. "1" for Ethereum Mainnet
    internal let chainId: String

    /// The wallet's address being used to sign in
    internal let walletAddress: String

    /// Define the parameters for a SIWE message
    public init(
        appDomain: String,
        appUri: String,
        chainId: String,
        walletAddress: String
    ) {
        self.appDomain = appDomain
        self.appUri = appUri
        self.chainId = chainId
        self.walletAddress = walletAddress
    }
}
