import Foundation

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

    /// The shared Instance for privy
    public static let shared = Privy()

    /**
     The JWT token provider used for requesting token

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

    /// The user auth state
    public private(set) var authState = AuthState.unauthenticated {
        didSet {
            onAuthStateChange?(authState)
        }
    }

    /// The current appId
    public private(set) var appId: String?


    /// The App configuration
    public private(set) var config: PrivyConfig?

    /// The App Client configuration
    public private(set) var clientConfig: PrivyClientConfig?

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
     let config = PrivyConfig(appId: "")
     Privy.shared.configure(
         config: config,
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
    }

    /**
     Login with JWT
     # Returns
            Returns the users object
     # Code
     ```
     do {
         _ = try await Privy.shared.loginWithJwt()
     } catch {
         print(error)
     }
     ```
    */
    public func loginWithJwt() async throws -> User {
        guard privyState == .ready else {
            throw NSError()
        }

        guard (try await tokenProvider?()) != nil else {
            throw NSError(domain: "PrivyError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Token provider not set or failed to provide a token"])
        }

        // privy api call to login
        //if successful then change authState to authenticated
        // if failed throw
        let user = User(
            id: "1",
            linkedAccount: []
        )

//        if config?.shouldWalletOnLogin == true && !user.linkedAccount.contains(where: { $0 is WalletAccount }) {
//            // create a wallet
//            // iframe
//            //proxy.createWallet()
//            // wa
//            //authState = .authenticated(user, .connnected(WalletProvider(address: "")))
//        } else {
//            //authState = .authenticated(user, )
//        }

        return user
    }



    private init() {

    }
}
