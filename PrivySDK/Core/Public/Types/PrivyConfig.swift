import Foundation

/// Configuration for your application's privy client instance
public struct PrivyConfig: Sendable {
    /// Unique ID for your application, can be retrieved from the developer dashboard @ `https://console.privy.io/apps/<your-app-id>/settings`
    public let appId: String

    /// Unique ID for your application client, can be retrieved from the developer dashboard @ `https://console.privy.io/apps/<your-app-id>/settings?setting=clients`
    public let appClientId: String?

    /// The desired log level in order to aid in debugging
    public let loggingConfig: PrivyLoggingConfig?

    /// The configuration for third party auth. Required if using third party auth as your login method.
    public let customAuthConfig: PrivyLoginWithCustomAuthConfig?

    /// The configuration for MFA (Multi-Factor Authentication) behavior.
    public let mfaConfig: PrivyMFAConfig

    /// Configuration for embedded wallet behavior.
    public let embeddedWalletConfig: PrivyEmbeddedWalletConfig

    /// Optional handler invoked synchronously with lightweight diagnostic events (breadcrumbs) as
    /// the SDK progresses through key flows. Use this to route breadcrumbs to your own analytics
    /// or observability tooling.
    public let breadcrumbHandler: PrivyBreadcrumbHandler?

    /// Define the configuration object for the Privy SDK
    public init(
        appId: String,
        appClientId: String,
        loggingConfig: PrivyLoggingConfig? = nil,
        customAuthConfig: PrivyLoginWithCustomAuthConfig? = nil,
        mfaConfig: PrivyMFAConfig? = nil,
        embeddedWalletConfig: PrivyEmbeddedWalletConfig? = nil,
        breadcrumbHandler: PrivyBreadcrumbHandler? = nil
    ) {
        self.appId = appId
        self.appClientId = appClientId
        self.loggingConfig = loggingConfig
        self.customAuthConfig = customAuthConfig
        self.mfaConfig = mfaConfig ?? .empty
        self.embeddedWalletConfig = embeddedWalletConfig ?? PrivyEmbeddedWalletConfig()
        self.breadcrumbHandler = breadcrumbHandler
    }
}

/// The configuration object for logs published by the Privy SDK
public struct PrivyLoggingConfig: Sendable {
    /// The desired log level in order to aid in debugging
    public let logLevel: PrivyLogLevel

    /// If set, Privy will call this closure with the log level and log message when attempting to log a message. This allows you to use your preferred logging framework.
    /// If unset, Privy will print the log to console.
    public let logMessage: (@Sendable (PrivyLogLevel, String) -> Void)?

    /// Define the configuration object for Privy logs
    public init(
        logLevel: PrivyLogLevel,
        logMessage: (@Sendable (PrivyLogLevel, String) -> Void)? = nil
    ) {
        self.logLevel = logLevel
        self.logMessage = logMessage
    }
}

/// The configuration for third party auth. Required if using third part auth as your login method.
/// - Parameters
///   - tokenProvider The logic to retrieve the access token from your third party authentication provider.
///   This callback will be invoked  when [Privy.customJwt.loginWithCustomAccessToken] is called,
///   when  attempting to restore a prior session, or when refreshing a session.
public struct PrivyLoginWithCustomAuthConfig: Sendable {
    /// The logic to retrieve the access token from your third party authentication provider. This callback will be invoked  when [Privy.customAuth.loginWithCustomAccessToken] is called, when  attempting to restore a prior session, or when refreshing a session.
    public let tokenProvider: TokenProvider

    /// Define the configuration object for custom third party auth
    public init(tokenProvider: @escaping TokenProvider) {
        self.tokenProvider = tokenProvider
    }
}

/// Configuration for MFA (Multi-Factor Authentication) behavior.
///
/// Use this configuration to set up automatic MFA prompts when operations require
/// multi-factor authentication. The delegate will be called when an operation fails
/// due to missing MFA, allowing you to present a custom UI to the user.
///
/// ## Example
/// ```swift
/// let mfaConfig = PrivyMFAConfig(
///     delegate: myMfaHandler,
///     mfaTimeout: .seconds(300) // 5 minutes
/// )
///
/// let config = PrivyConfig(
///     appId: "your-app-id",
///     appClientId: "your-client-id",
///     mfaConfig: mfaConfig
/// )
/// ```
public struct PrivyMFAConfig: Sendable {
    /// Default timeout duration for MFA verification (5 minutes)
    internal static let defaultTimeout: Duration = .seconds(300)

    /// An empty MFA configuration with no delegate and default timeout.
    internal static let empty = PrivyMFAConfig()

    /// The delegate to handle MFA prompts.
    ///
    /// This delegate will be called when an operation requires MFA verification.
    /// You should present your custom MFA UI and call the appropriate verification method.
    public let delegate: PrivyMfaPromptDelegate?

    /// The timeout duration for MFA verification.
    ///
    /// Defaults to 5 minutes. After this duration, blocked operations
    /// will fail with a `timeoutOnMfa` error.
    public let mfaTimeout: Duration

    /// Define the configuration object for MFA
    /// - Parameters:
    ///   - delegate: The delegate to handle MFA prompts.
    ///   - mfaTimeout: The timeout duration for MFA verification. Defaults to 5 minutes.
    public init(
        delegate: PrivyMfaPromptDelegate,
        mfaTimeout: Duration = .seconds(300)
    ) {
        self.delegate = delegate
        self.mfaTimeout = mfaTimeout
    }

    /// Internal initializer for an empty MFA configuration.
    internal init() {
        self.delegate = nil
        self.mfaTimeout = .seconds(300)
    }
}

/// Configuration for embedded wallet behavior.
public struct PrivyEmbeddedWalletConfig: Sendable {
    /// Whether to disable automatic wallet migration on authentication.
    ///
    /// When `false` (the default), wallets are automatically migrated to the TEE stack
    /// when a user authenticates. Set to `true` to disable this behavior and instead
    /// trigger migration manually via ``PrivyUser/migrateWallets()``.
    public let disableAutomaticMigration: Bool

    /// Define the configuration object for embedded wallets
    /// - Parameter disableAutomaticMigration: Whether to disable automatic wallet migration. Defaults to `false`.
    public init(
        disableAutomaticMigration: Bool = false
    ) {
        self.disableAutomaticMigration = disableAutomaticMigration
    }
}
