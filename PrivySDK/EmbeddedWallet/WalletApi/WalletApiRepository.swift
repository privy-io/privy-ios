import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var walletApiRepository: Factory<WalletApiRepository> {
        self { WalletApiRepositoryImpl() }.shared
    }
}

internal protocol WalletApiRepository: Sendable {
    func createWallet(_ params: WalletApiCreateRequest, token: String) async throws -> WalletApiCreateResponse
    func rpc(_ params: WalletApiRpcRequest, walletId: String, token: String) async throws -> WalletApiRpcResponse

    /// Fetches a wallet by its ID.
    ///
    /// - Parameters:
    ///   - walletId: The ID of the wallet to fetch.
    ///   - token: The auth token for the request.
    ///
    /// - Returns: The wallet API response.
    func getWallet(walletId: String, token: String) async throws -> WalletApiGetResponse

    /// Updates a wallet's properties.
    ///
    /// - Parameters:
    ///   - walletId: The ID of the wallet to update.
    ///   - params: The update request containing the fields to change.
    ///   - token: The auth token for the request.
    ///
    /// - Returns: The updated wallet API response.
    func updateWallet(walletId: String, params: WalletApiUpdateWalletRequest, token: String) async throws -> WalletApiUpdateWalletResponse

    /// Fetches transaction history for a wallet.
    ///
    /// - Parameters:
    ///   - walletId: The ID of the wallet to fetch transactions for.
    ///   - params: Query parameters for the transaction history request.
    ///   - token: The auth token for the request.
    ///
    /// - Returns: The transactions API response.
    func getTransactions(walletId: String, params: GetTransactionsParams, token: String) async throws -> WalletTransactionsResponse

    /// Starts a wallet import and returns the public key to encrypt the wallet's entropy to.
    ///
    /// Each call replaces any pending import for the same address, invalidating the key a previous
    /// call returned.
    ///
    /// - Parameters:
    ///   - params: The address, chain and entropy type of the wallet to import.
    ///   - token: The auth token for the request.
    ///
    /// - Returns: The public key for the import.
    func initImport(_ params: WalletApiImportInitRequest, token: String) async throws -> WalletApiImportInitResponse

    /// Completes a wallet import with the encrypted entropy.
    ///
    /// - Parameters:
    ///   - params: The wallet to import, with its HPKE-encrypted entropy.
    ///   - token: The auth token for the request.
    ///
    /// - Returns: The imported wallet.
    func submitImport(_ params: WalletApiImportSubmitRequest, token: String) async throws -> WalletApiCreateResponse
}

private final class WalletApiRepositoryImpl: WalletApiRepository {
    private let networkService: NetworkService = resolve(\PrivyContainer.networkService)
    private let userSigner: UserSigner = resolve(\PrivyContainer.userSigner)
    private let config: PrivyConfig = resolve(\PrivyContainer.config)
    private let logger: Logger = resolve(\PrivyContainer.logger)

    internal func createWallet(_ params: WalletApiCreateRequest, token: String) async throws -> WalletApiCreateResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/wallets", token: token)

        request.httpBody = try JSONEncoder().encode(params)

        return try await request.execute()
    }

    internal func initImport(_ params: WalletApiImportInitRequest, token: String) async throws -> WalletApiImportInitResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/wallets/import/init", token: token)

        request.httpBody = try JSONEncoder().encode(params)

        return try await request.execute()
    }

    internal func submitImport(_ params: WalletApiImportSubmitRequest, token: String) async throws -> WalletApiCreateResponse {
        var request = try await self.networkService.makeRequest(path: "/api/v1/wallets/import/submit", token: token)

        request.httpBody = try JSONEncoder().encode(params)

        return try await request.execute()
    }

    internal func rpc(_ params: WalletApiRpcRequest, walletId: String, token: String) async throws -> WalletApiRpcResponse {
        let path = "/api/v1/wallets/\(walletId)/rpc"
        let url = "\(config.baseUrl)\(path)"

        let payload = WalletApiPayload(
            version: 1,
            url: url,
            method: "POST",
            headers: ["privy-app-id": config.appId],
            body: params
        )

        let signature = try await userSigner.signature(for: payload)

        var request = try await self.networkService.makeRequest(path: path, token: token)
        request.setValue(signature, forHTTPHeaderField: "privy-authorization-signature")
        request.httpBody = try JSONEncoder().encode(params)

        return try await request.execute()
    }

    internal func getWallet(walletId: String, token: String) async throws -> WalletApiGetResponse {
        let path = "/api/v1/wallets/\(walletId)"
        logger.verbose("GET wallet \(walletId)")
        let request = try await self.networkService.makeRequest(path: path, token: token, httpMethod: "GET")

        let response: WalletApiGetResponse = try await request.execute()
        logger.verbose("GET wallet \(walletId) succeeded")
        return response
    }

    internal func updateWallet(walletId: String, params: WalletApiUpdateWalletRequest, token: String) async throws -> WalletApiUpdateWalletResponse {
        let path = "/api/v1/wallets/\(walletId)"
        let url = "\(config.baseUrl)\(path)"

        logger.verbose("PATCH wallet \(walletId)")

        let payload = WalletApiPayload(
            version: 1,
            url: url,
            method: "PATCH",
            headers: ["privy-app-id": config.appId],
            body: params
        )

        let signature = try await userSigner.signature(for: payload)

        var request = try await self.networkService.makeRequest(path: path, token: token, httpMethod: "PATCH")
        request.setValue(signature, forHTTPHeaderField: "privy-authorization-signature")
        request.httpBody = try JSONEncoder().encode(params)

        let response: WalletApiUpdateWalletResponse = try await request.execute()
        logger.verbose("PATCH wallet \(walletId) succeeded")
        return response
    }

    internal func getTransactions(walletId: String, params: GetTransactionsParams, token: String) async throws -> WalletTransactionsResponse {
        let path = "/api/v1/wallets/\(walletId)/transactions"
        logger.verbose("GET transactions for wallet \(walletId)")

        var queryItems: [URLQueryItem] = [URLQueryItem(name: "chain", value: params.chain.queryValue)]
        if let assets = params.assets {
            for asset in assets {
                queryItems.append(URLQueryItem(name: "asset", value: asset))
            }
        }
        if let tokens = params.tokens {
            for tokenAddress in tokens {
                queryItems.append(URLQueryItem(name: "token", value: tokenAddress))
            }
        }
        if let txHash = params.txHash {
            queryItems.append(URLQueryItem(name: "tx_hash", value: txHash))
        }
        if let limit = params.limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        if let cursor = params.cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let includeArchived = params.includeArchived {
            queryItems.append(URLQueryItem(name: "include_archived", value: includeArchived ? "true" : "false"))
        }

        let request = try await self.networkService.makeRequest(
            path: path,
            token: token,
            httpMethod: "GET",
            queryItems: queryItems
        )

        let response: WalletTransactionsResponse = try await request.execute()
        logger.verbose("GET transactions for wallet \(walletId) succeeded")
        return response
    }
}
