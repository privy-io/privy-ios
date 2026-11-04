import Foundation

/**
 * The Privy SDK entry point.
 * Create an instance with your config by calling `PrivySdk.initialize(config: PrivyConfig)` to interact with privy
 */
public protocol Privy: Sendable {
    // MARK: Authentication state

    /**
     * When the PrivySDK is initialized, Privy attempts to asynchronously restore the user's previous session if they were previously logged in.
     * During this time, the user's authentication state will be not ready. Call this function to await Privy ready state.
     * It is **highly** recommended to call this function before executing any calls to Privy.
     */
    @available(*, deprecated, message: "Use 'getAuthState() async -> AuthState' instead, which handles awaiting ready under the hood.")
    func awaitReady() async

    /**
     * An async function that returns the user's authentication state after ensuring
     * all SDK initialization tasks have completed running, such as restoring / refreshing a prior
     * authenticated session.
     *
     * - Returns:  The user's authentication state
     */
    func getAuthState() async -> AuthState

    /// Returns the cached authentication state without triggering a session refresh.
    ///
    /// Unlike ``getAuthState()``, this method does **not** wait for SDK initialization to complete
    /// and does **not** trigger a token refresh against the server. It returns whatever auth state
    /// the SDK currently holds in memory.
    ///
    /// **When to use:**
    /// - In iOS background tasks or app extensions (e.g. `DeviceActivityMonitor`) where triggering
    ///   a refresh is unsafe — iOS may kill the process mid-refresh, causing the locally stored
    ///   refresh token to become stale and ultimately invalidating the session.
    /// - When you need a quick, synchronous read of the auth state for UI purposes and can tolerate
    ///   a potentially stale value.
    ///
    /// **When NOT to use:**
    /// - In foreground app flows where you need a guaranteed up-to-date auth state. Use
    ///   ``getAuthState()`` instead, which ensures initialization is complete and the session
    ///   has been verified/refreshed.
    ///
    /// - Returns: The current cached authentication state. May return ``AuthState/notReady`` if the
    ///   SDK has not yet finished initializing.
    func getAuthStateWithoutRefresh() -> AuthState

    /**
     * The privy user object. Will be non null if the user is authenticated.
     * Be sure to call `awaitReady` before accessing the user.
     */
    @available(*, deprecated, message: "Use 'getUser() async -> PrivyUser?' instead, which handles awaiting ready under the hood.")
    var user: PrivyUser? { get }

    /**
     * An async function that returns the currently authenticated user, if there is one, or null otherwise,
     * after awaiting SDK initialization tasks are complete.
     *
     * - Returns:  The authenticated user, if exists, or null otherwise
     */
    func getUser() async -> PrivyUser?

    /// The user's current auth state.
    @available(*, deprecated, message: "Use 'getAuthState() async -> AuthState' instead, which handles awaiting ready under the hood. If you are reading auth state from a background task or extension where triggering a refresh is unsafe, use 'getAuthStateWithoutRefresh()' instead.")
    var authState: AuthState { get }

    /// An async stream that emits auth state updates
    var authStateStream: AsyncStream<AuthState> { get }

    // MARK: Login methods

    /// Entry point for login with email flow
    var email: LoginWithEmail { get }

    /// Entry point for login with SMS flow
    var sms: LoginWithSms { get }

    /// Entry point for SIWE flow
    var siwe: LoginWithSiwe { get }

    /// Entry point for SIWS flow
    var siws: LoginWithSiws { get }

    /// Entry point for login with custom access token flow
    var customJwt: LoginWithCustomAccessToken { get }

    /// Entry point for Oauth flow
    var oAuth: LoginWithOAuth { get }

    /// Entry point for passkey authentication flow
    var passkey: LoginWithPasskey { get }

    /// Entry point for MFA operations at the Privy level.
    ///
    /// Use `privy.mfa.setConfig(_:)` to configure MFA prompt handling, and
    /// `privy.mfa.resumeBlockedActions()` to unblock operations waiting for MFA verification.
    var mfa: PrivyMfa { get }

    /**
     * If the PrivySDK was initialized while the device had no network connectivity, the `authState`
     * might remain as `AuthState.authenticatedUnverified`. Whenever you determine the device
     * regains connectivity, call `onNetworkRestored`, which will attempt to restore the prior user
     * session. After calling this, check `Privy.authState` to validate the user's authentication
     * state.
     *
     * A call to `onNetworkRestored` after the user's auth state had already been determined will
     * result in a no op, so you can safely call this whenever.
     */
    func onNetworkRestored() async
}
