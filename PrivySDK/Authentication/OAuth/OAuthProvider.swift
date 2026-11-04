import Foundation

/// An OAuth/Social provider that allows account access via Privy
public enum OAuthProvider: Sendable {
    /// Google Sign-In
    case google
    /// Sign in with Apple
    case apple
    /// Login with X
    case twitter
    /// Login with Discord
    case discord
    /// Login with Telegram
    case telegram
}
