import Foundation
internal import FactoryKit

internal protocol EmbeddedWalletManager: Sendable {
    /**
     Creates a new embedded wallet on the specified chain. Currently only ethereum and solana are supported.

     - Parameters:
       - chainType: Specifies the chain to create the wallet on.
       - allowAdditional: Specifies if more than one wallet can be created.
       - timeout: The timeout duration for wallet creation. Defaults to 60 seconds.

     - Throws: An error if wallet creation fails, which could happen if:
        - There is no authenticated user
        - If an embedded wallet already exists and allowAdditional was set to false
        - If a user already has 9 or more wallets
        - If the network call to create the wallet fails
     - Returns: The newly created wallet
     */
    func createWallet(chainType: ChainType, allowAdditional: Bool, timeout: Duration) async throws -> (any EmbeddedWalletAccount)

    func logout() async
}

internal extension EmbeddedWalletManager {
    // Convience method that delegates to createWallet(chainType:allowAdditional:timeout:)
    // with allowAdditional param defaulting to false and timeout defaulting to 60 seconds
    func createWallet(chainType: ChainType) async throws -> (any EmbeddedWalletAccount) {
        return try await createWallet(chainType: chainType, allowAdditional: false, timeout: .seconds(60))
    }

    // Convience method that delegates to createWallet(chainType:allowAdditional:timeout:)
    // with timeout defaulting to 60 seconds
    func createWallet(chainType: ChainType, allowAdditional: Bool) async throws -> (any EmbeddedWalletAccount) {
        return try await createWallet(chainType: chainType, allowAdditional: allowAdditional, timeout: .seconds(60))
    }
}
