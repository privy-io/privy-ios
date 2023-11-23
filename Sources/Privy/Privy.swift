import Foundation
import HeadlessSDK

/**
 The Privy SDK Main Class.
 Always use Privy.shared singleton to interact with privy

 # Code
 ```
 Privy.shared
 ```
 */
public final class Privy {
    public typealias TokenProvider = () async throws -> String
    public typealias AuthStateChangeCallback = (AuthState) -> Void
    public typealias PrivyStateChangeCallback = (PrivyState) -> Void

    /// The shared Privy instance
    public static let shared = Privy()

    /**
     The provider used for requesting custom access tokens

    # Code
    ```
    Privy.shared.tokenProvider = {
        // Client logic to provide the JWT token
        // This might involve network requests or accessing secure storage
        return await fetchTokenFromServer() // Example function
    }
    ```
    */
    public var tokenProvider: TokenProvider?

    /// The privy SDK state
    public private(set) var privyState = PrivyState.notReady {
        didSet {
            onPrivyStateChange?(privyState)
        }
    }

    /// The user's authenticated state
    public private(set) var authState = AuthState.unauthenticated {
        didSet {
            onAuthStateChange?(authState)
        }
    }

    /// The app configuration
    public private(set) var config: PrivyConfig?

    /// The App Client configuration
    private var clientConfig: PrivyClientConfig?

    /**
    The Privy State change callback

    # Code
    ```
    Privy.shared.onPrivyStateChange = { newPrivyState in
        print("Privy state changed to: \(newPrivyState)")
    }
    ```
    */
    public var onPrivyStateChange: PrivyStateChangeCallback?

    /**
     The Auth State change callback

     # Code
     ```
     Privy.shared.onAuthStateChange = { newAuthState in
         print("Authentication state changed to: \(newAuthState)")
     }
     ```
     */
    public var onAuthStateChange: AuthStateChangeCallback?

    // MARK: - Usage

    /**
     This method allows you to configure your app

     # Code
     ```
     Privy.shared.configure(
         config: PrivyConfig(appId: "insert-your-privy-app-id"),
         tokenProvider: {
             // Implementation to provide a JWT token
             return await fetchToken()
         }
     )
     ```
    */
    public func configure(config: PrivyConfig, tokenProvider: @escaping TokenProvider) {
        self.config = config
        self.tokenProvider = tokenProvider

        // get app configure
        // if successful
        clientConfig = PrivyClientConfig(shouldCreateWalletOnLogin: true)
        // setupIframewithiframe
        privyState = .ready
        //login
    }

    /**
     Login with custom access token
     # Returns
            Returns the user object. This method calls the tokenProvider callback
     # Code
     ```
     do {
         _ = try await Privy.shared.loginWithJwt()
     } catch {
         print(error)
     }
     ```
    */
    public func loginWithCustomAccessToken() async throws -> User {
        guard privyState == .ready else {
            throw NSError()
        }

        guard let token = try await tokenProvider?() else {
            throw NSError(domain: "PrivyError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Token provider not set or failed to provide a token"])
        }

        // privy api call to login
        //if successful then change authState to authenticated
        // if failed throw
        let user = User(
            id: "1",
            linkedAccounts: []
        )

        if clientConfig?.shouldCreateWalletOnLogin == true && !user.linkedAccounts.contains(where: { $0 is WalletAccount }) {
            // create a wallet
            // iframe
            //proxy.createWallet()
            // wa

            let walletCreator = WalletCreator()
            walletCreator.create()

            let provider = EmbeddedWalletProvider(chainId: "", rpcURL: "")
            authState = .authenticated(user, .connected(provider))
        } else {
            let provider = EmbeddedWalletProvider(chainId: "", rpcURL: "")
            authState = .authenticated(user, .connected(provider))
        }

        return user
    }

    /**
     Log out your user
     # Code
     ```
     Privy.shared.logout()
     ```
    */
    public func logout() {
        privyState = .notReady
        authState = .unauthenticated
    }

    private init() {
        HeadlessSDK.Privy.shared.state
    }
}
