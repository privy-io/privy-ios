import Foundation
@testable import PrivySDK

/// In-memory `WalletApiRepository` test double. Only the wallet create and import members are
/// stubbable today; every other member, and a stubbable member whose result is left `nil`,
/// fatal-errors if a test exercises it.
internal final class TestWalletApiRepository: WalletApiRepository, @unchecked Sendable {
    internal var initImportResult: Result<WalletApiImportInitResponse, Error>?
    internal private(set) var initImportRequests: [(params: WalletApiImportInitRequest, token: String)] = []

    internal var submitImportResult: Result<WalletApiCreateResponse, Error>?
    internal private(set) var submitImportRequests: [(params: WalletApiImportSubmitRequest, token: String)] = []

    internal var createWalletResult: Result<WalletApiCreateResponse, Error>?
    internal private(set) var createWalletRequests: [(params: WalletApiCreateRequest, token: String)] = []

    internal func initImport(_ params: WalletApiImportInitRequest, token: String) async throws -> WalletApiImportInitResponse {
        guard let initImportResult else { notStubbed("initImport") }
        initImportRequests.append((params, token))
        return try initImportResult.get()
    }

    internal func submitImport(_ params: WalletApiImportSubmitRequest, token: String) async throws -> WalletApiCreateResponse {
        guard let submitImportResult else { notStubbed("submitImport") }
        submitImportRequests.append((params, token))
        return try submitImportResult.get()
    }

    internal func createWallet(_ params: WalletApiCreateRequest, token: String) async throws -> WalletApiCreateResponse {
        guard let createWalletResult else { notStubbed("createWallet") }
        createWalletRequests.append((params, token))
        return try createWalletResult.get()
    }

    internal func rpc(_ params: WalletApiRpcRequest, walletId: String, token: String) async throws -> WalletApiRpcResponse {
        notStubbed("rpc")
    }

    internal func getWallet(walletId: String, token: String) async throws -> WalletApiGetResponse {
        notStubbed("getWallet")
    }

    internal func updateWallet(walletId: String, params: WalletApiUpdateWalletRequest, token: String) async throws -> WalletApiUpdateWalletResponse {
        notStubbed("updateWallet")
    }

    internal func getTransactions(walletId: String, params: GetTransactionsParams, token: String) async throws -> WalletTransactionsResponse {
        notStubbed("getTransactions")
    }

    private func notStubbed(_ member: String) -> Never {
        fatalError("TestWalletApiRepository.\(member) was called but isn't stubbed for this test.")
    }
}
