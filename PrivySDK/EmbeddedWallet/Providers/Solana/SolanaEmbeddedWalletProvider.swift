import Foundation

/// An embedded solana wallet provider for acting on a wallet
public protocol EmbeddedSolanaWalletProvider: Sendable {
    /// Request a signature on a Base64 encoded message or transaction
    /// - Parameters:
    ///     - message: Base64 encoded message or transaction
    ///
    /// - Returns: The Base64 encoded computed signature
    ///
    /// - Throws: an error if signing the message is unsuccessful
    func signMessage(message: String) async throws -> String

    ///  Signs a Solana transaction without broadcasting it.
    ///
    /// - Parameters:
    ///     - transaction: Solana transaction serialized as a byte array
    ///
    /// - Retruns: The Base64-encoded signed transaction
    ///
    func signTransaction(transaction: Data) async throws -> String

    /// Signs and broadcasts a Solana transaction.
    ///
    /// If the application is set up for TEE execution the RPC URL of the provided cluster is ignored,
    /// as will the configuration options, and Privy will be the one broadcasting the transaction.
    ///
    /// - Parameters:
    ///     - transaction: Solana transaction serialized as a byte array
    ///     - cluster: The Solana cluster where the transaction will be broadcasted.
    ///     - options: Optional configuration options for sending the transaction
    ///
    /// - Returns: The transaction hash
    ///
    /// - Throws: an error if signing the transaction is unsuccessful
    func signAndSendTransaction(transaction: Data, cluster: SolanaCluster, options: SolanaSendOptions?) async throws -> String
}

public extension EmbeddedSolanaWalletProvider {
    /// Signs and broadcasts a Solana transaction.
    ///
    /// If the application is set up for TEE execution the RPC URL of the provided cluster is ignored,
    /// and Privy will be the one broadcasting the transaction.
    ///
    /// - Parameters:
    ///     - transaction: Solana transaction serialized as a byte array
    ///     - cluster: The Solana cluster where the transaction will be broadcasted.
    ///
    /// - Returns: The transaction hash
    ///
    /// - Throws: an error if signing the transaction is unsuccessful
    func signAndSendTransaction(transaction: Data, cluster: SolanaCluster) async throws -> String {
        return try await self.signAndSendTransaction(transaction: transaction, cluster: cluster, options: nil)
    }
}
