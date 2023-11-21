import Foundation


/// The Privy SDK Main Class
public class Privy {

    /// The shared Instance for privy
    public static let shared = Privy()


    /// The privcy state
    public private(set) var privyState = PrivyState.notReady


    /// The user auth state
    public private(set) var authState = AuthState.unauthenticated


    /// The current appId
    public private(set) var appId: String?


    /// The App configuration
    public private(set) var config: PrivyConfig?

    // MARK: - Usage

    /// Configure your app with your aoo id
    /// - Parameter appId: Your app  id from the console
    public func configure(appId: String) {
        self.appId = appId
        // get app configure
        // if successful
        config = PrivyConfig(shouldWalletOnLogin: true)
        // setupIframewithiframe
        privyState = .ready
    }


    /// Login with JWT
    /// - Parameter token: Auth token
    /// - Returns: Returns the users object
    public func loginWithJwt(with token: String) async throws -> User {
        guard privyState == .ready else {
            throw NSError()
        }

        //privy api call to login
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
