// swiftlint:disable missing_docs
import Foundation

public struct ChainInfo {
    public let id: Int
    public let name: String
    public let network: String
    public let nativeCurrency: NativeCurrency
    public let rpcUrls: RpcUrls
    public let blockExplorers: BlockExplorers
    public let contracts: Contracts?
    public let testnet: Bool

    public init(id: Int, name: String, network: String, nativeCurrency: NativeCurrency, rpcUrls: RpcUrls, blockExplorers: BlockExplorers, contracts: Contracts? = nil, testnet: Bool = false) {
        self.id = id
        self.name = name
        self.network = network
        self.nativeCurrency = nativeCurrency
        self.rpcUrls = rpcUrls
        self.blockExplorers = blockExplorers
        self.contracts = contracts
        self.testnet = testnet
    }
}

// MARK: - NativeCurrency

public struct NativeCurrency {
    public let name: String
    public let symbol: String
    public let decimals: Int
}

// MARK: - RpcUrls and Subcomponents

public struct RpcUrl {
    public let http: [String]
    public let webSocket: [String]?

    internal init(http: [String], webSocket: [String]? = nil) {
        self.http = http
        self.webSocket = webSocket
    }
}

public struct RpcUrls {
    public let `default`: RpcUrl
    public let `public`: RpcUrl
    public let blast: RpcUrl?
    public let alchemy: RpcUrl?
    public let infura: RpcUrl?
    public let privy: RpcUrl?

    public init(
        `default`: RpcUrl,
        `public`: RpcUrl,
        alchemy: RpcUrl? = nil,
        infura: RpcUrl? = nil,
        blast: RpcUrl? = nil,
        privy: RpcUrl? = nil
    ) {
        self.default = `default`
        self.public = `public`
        self.alchemy = alchemy
        self.infura = infura
        self.blast = blast
        self.privy = privy
    }
}

// MARK: - BlockExplorers and Subcomponents

public struct BlockExplorer {
    public let name: String
    public let url: String
}

public struct BlockExplorers {
    public let etherscan: BlockExplorer
    public let `default`: BlockExplorer?
    public let filscan: BlockExplorer?

    public init(etherscan: BlockExplorer, `default`: BlockExplorer? = nil, filscan: BlockExplorer? = nil) {
        self.etherscan = etherscan
        self.default = `default`
        self.filscan = filscan
    }
}

// MARK: - Contracts and Subcomponents

public struct Contracts {
    public let multicall3: Multicall3
}

public struct Multicall3 {
    public let address: String
    public let blockCreated: Int
}
