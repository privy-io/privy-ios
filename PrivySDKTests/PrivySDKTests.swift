import XCTest
@testable import PrivySDK

internal final class PrivySDKTests: XCTestCase {
    /// Verifies the DI dependency graph has no circular dependencies.
    ///
    /// FactoryKit's built-in circular dependency chain detection (DEBUG only)
    /// will fatalError if the same type appears in the resolution chain more
    /// than `dependencyChainTestMax` times (default: 8). By instantiating
    /// PrivyImpl, we transitively resolve nearly all registered factories
    /// through the normal dependency graph.
    @MainActor
    internal func testNoCyclicDependenciesInDependencyGraph() {
        // Reset container to clear cached singletons from prior tests
        PrivyContainer.shared.manager.reset()

        // Initialize with minimal test config
        let config = PrivyConfig(appId: "test-app-id", appClientId: "test-client-id")
        PrivyContainer.shared.initialize(config: config)

        // Instantiate PrivyImpl — this transitively resolves ~55 factories
        // including all stored properties (authManager, embeddedWallet,
        // login methods, mfa, etc.) and their transitive dependencies.
        let _ = PrivyImpl()
    }

    internal func testChainTypeCodableUsesWalletApiValues() throws {
        for chainType in [ChainType.ethereum, .solana] {
            let encoded = try JSONEncoder().encode(chainType)
            XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"\(chainType.rawValue)\"")
            XCTAssertEqual(try JSONDecoder().decode(ChainType.self, from: encoded), chainType)

            let request = try JSONEncoder().encode(WalletApiCreateRequest(chainType: chainType))
            XCTAssertEqual(String(data: request, encoding: .utf8), "{\"chain_type\":\"\(chainType.rawValue)\"}")

            let response = "{\"id\":\"wallet-id\",\"address\":\"address\",\"chain_type\":\"\(chainType.rawValue)\"}".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(WalletApiCreateResponse.self, from: response)
            XCTAssertEqual(decoded.chainType, chainType)
        }
    }

    internal func testChainTypeDecodingRejectsUnsupportedChains() {
        let unknownChain = #""bitcoin""#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ChainType.self, from: unknownChain))
        XCTAssertEqual(ChainType(chainType: "bitcoin"), .ethereum)
    }
}
