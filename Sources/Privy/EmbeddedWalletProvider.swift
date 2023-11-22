//
//  EmbeddedWalletProvider.swift
//  HeadlessSDK
//
//  Created by Dalu Udeogu on 2023-11-21.
//

import Foundation

extension EmbeddedWalletProvider {

    /// The EmbeddedWalletProvider request
    public struct Request {

        /// The request method
        public let method: String

        /// The request parameter
        public let params: [String: String]
    }
}

/// The embedded wallet provider
public class EmbeddedWalletProvider {
    /// The wallet chain id
    private var chainId: String

    /// The wallet current rpc URL String
    private var rpcURL: String

    internal init(chainId: String, rpcURL: String) {
        self.chainId = chainId
        self.rpcURL = rpcURL
    }

    /// The request
    /// - Parameter request: The Wallet request
    /// - Returns: The return can be string or [String: String]
    public func request(_ request: Request) async throws -> Any {
        return ""
    }

    // TODO:
//    /// get your wallet address
//    /// - Returns: This returns your wallet address
//    public func getAddress() async throws -> String {
//        ""
//    }
//
//    /// Switch the current chain
//    /// - Parameter id: pass the chain id you want to switch to
//    public func switchChain(id: String) async throws {
//    }
//
//    /// Signing message on your wallet
//    /// - Parameter message: this is the message you want to sign
//    /// - Returns: This returns the hex string
//    public func signMessage(message: String) async throws -> String {
//        ""
//    }
//
//    /// The sign type Data
//    public func signTypedData() async throws {
//    }
//
//    /// Prepare your transaction
//    /// - Parameter request: This is the trasaction request info
//    /// - Returns: The modify trasaction request
//    public func prepareTransactionRequest(_ request: TransactionRequest) async throws -> TransactionRequest {
//        TransactionRequest(account: request.account, to: request.to, value: request.value)
//    }
//
//    /// Prepare your transaction
//    /// - Parameter request: This is the trasaction request info
//    /// - Returns: A hex string
//    public func sendRawTransaction(_ signature: String) async throws -> String {
//        ""
//    }
//
//    /// Prepare your transaction
//    /// - Parameter request: This is the trasaction request info
//    /// - Returns: A hex string
//    public func sendTransaction(_ request: TransactionRequest) async throws -> String {
//        ""
//    }
//
//    /// sign your transaction
//    /// - Parameter request: This is the trasaction request info
//    /// - Returns: A hex string
//    public func signTransaction(_ request: TransactionRequest) async throws -> String {
//        ""
//    }
}


extension EmbeddedWalletProvider {

    /// The Transaction Request data
    public struct TransactionRequest {
        public let account: String
        public let to: String
        public let value: UInt64
    }

    /// The Transaction Response data
    public struct TransactionResponse {}
}
