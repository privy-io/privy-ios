import Foundation

/// Metadata about the user who currently owns the conflicting login method.
///
/// These fields identify a *different* Privy user than the one currently authenticated, and are
/// intended only for rendering a confirmation prompt (e.g. "transfer this email from <display name>?").
/// Avoid logging, persisting, or sending this data to analytics — doing so can leak another user's
/// identifiers.
public struct ConflictingUserMetadata: Sendable {
    /// The embedded wallet address of the conflicting user, if any.
    public let embeddedWalletAddress: String?
    /// The Farcaster-linked embedded wallet address of the conflicting user, if any.
    public let farcasterEmbeddedAddress: String?
    /// A display name for the conflicting account (e.g. the email address or OAuth display name).
    public let displayName: String?
    /// OAuth user info fields associated with the conflicting account, if any.
    public let oAuthUserInfo: [String: String?]?
}
