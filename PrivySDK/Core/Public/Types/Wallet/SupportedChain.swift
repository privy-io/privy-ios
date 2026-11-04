// swiftlint:disable missing_docs
import Foundation

public enum SupportedChain: CaseIterable {
    case mainnet
    case sepolia
    case goerli
    case base
    case baseGoerli
    case baseSepolia
    case optimism
    case matic
    case filecoinMainnet
    case optimismGoerli
    case arbitrum
    case celo
    case celoAlfajores
    case avalancheFuji
    case avalanche
    case lineaTestnet
    case lineaMainnet
    case polygonMumbai
    case filecoinCalibration
    case arbitrumGoerli
}

extension SupportedChain {
    public var chainInfo: ChainInfo {
        switch self {
        case .mainnet:
            ChainInfo(
                id: 1,
                name: "Ethereum",
                network: "homestead",
                nativeCurrency: .init(name: "Ether", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://cloudflare-eth.com"]),
                    public: .init(http: ["https://cloudflare-eth.com"]),
                    alchemy: .init(http: ["https://eth-mainnet.g.alchemy.com/v2"], webSocket: ["wss://eth-mainnet.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://mainnet.infura.io/v3"], webSocket: ["wss://mainnet.infura.io/ws/v3"]),
                    privy: .init(http: ["https://mainnet.rpc.privy.systems"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Etherscan", url: "https://etherscan.io"),
                    default: .init(name: "Etherscan", url: "https://etherscan.io")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 14353601)
                )
            )
        case .sepolia:
            ChainInfo(
                id: 11155111,
                name: "Sepolia",
                network: "sepolia",
                nativeCurrency: .init(name: "Sepolia Ether", symbol: "SEP", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://rpc.sepolia.org"]),
                    public: .init(http: ["https://rpc.sepolia.org"]),
                    alchemy: .init(http: ["https://eth-sepolia.g.alchemy.com/v2"], webSocket: ["wss://eth-sepolia.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://sepolia.infura.io/v3"], webSocket: ["wss://sepolia.infura.io/ws/v3"]),
                    privy: .init(http: ["https://sepolia.rpc.privy.systems"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Etherscan", url: "https://sepolia.etherscan.io"),
                    default: .init(name: "Etherscan", url: "https://sepolia.etherscan.io")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 6507670)
                ),
                testnet: true
            )
        // TODO: Deprecate
        case .goerli:
            ChainInfo(
                id: 5,
                name: "Goerli",
                network: "goerli",
                nativeCurrency: .init(name: "Goerli Ether", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://rpc.ankr.com/eth_goerli"]),
                    public: .init(http: ["https://rpc.ankr.com/eth_goerli"]),
                    alchemy: .init(http: ["https://eth-goerli.g.alchemy.com/v2"], webSocket: ["wss://eth-goerli.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://goerli.infura.io/v3"], webSocket: ["wss://goerli.infura.io/ws/v3"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Etherscan", url: "https://goerli.etherscan.io"),
                    default: .init(name: "Etherscan", url: "https://goerli.etherscan.io")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 6507670)
                )
            )
        case .base:
            ChainInfo(
                id: 8453,
                name: "Base",
                network: "base",
                nativeCurrency: .init(name: "Base", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://mainnet.base.org"]),
                    public: .init(http: ["https://mainnet.base.org"]),
                    privy: .init(http: ["https://base-mainnet.rpc.privy.systems"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Basescout", url: "https://base.blockscout.com")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 5022)
                )
            )
        // TODO: deprecate
        case .baseGoerli:
            ChainInfo(
                id: 84531,
                name: "Base Goerli",
                network: "base-goerli",
                nativeCurrency: .init(name: "Base Goerli", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://goerli.base.org"]),
                    public: .init(http: ["https://goerli.base.org"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Basescan", url: "https://goerli.basescan.org"),
                    default: .init(name: "Basescan", url: "https://goerli.basescan.org")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 1376988)
                ),
                testnet: true
            )
        case .baseSepolia:
            ChainInfo(
                id: 84532,
                name: "Base Sepolia",
                network: "base-sepolia",
                nativeCurrency: .init(
                    name: "Ether",
                    symbol: "ETH",
                    decimals: 18
                ),
                rpcUrls: .init(
                    default: .init(http: ["https://sepolia.base.org"]),
                    public: .init(http: ["https://sepolia.base.org"]),
                    privy: .init(http: ["https://base-sepolia.rpc.privy.systems"])
                ),
                blockExplorers: .init(
                    etherscan: .init(
                        name: "BaseScan",
                        url: "https://sepolia.basescan.org/"
                    ),
                    default: .init(
                        name: "Blockscout",
                        url: "https://base-sepolia.blockscout.com"
                    )
                ),
                contracts: .init(
                    multicall3: .init(
                        address: "0xca11bde05977b3631167028862be2a173976ca11",
                        blockCreated: 1059647
                    )
                ),
                testnet: true
            )
        case .optimism:
            ChainInfo(
                id: 10,
                name: "OP Mainnet",
                network: "optimism",
                nativeCurrency: .init(name: "Ether", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://mainnet.optimism.io"]),
                    public: .init(http: ["https://mainnet.optimism.io"]),
                    alchemy: .init(http: ["https://opt-mainnet.g.alchemy.com/v2"], webSocket: ["wss://opt-mainnet.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://optimism-mainnet.infura.io/v3"], webSocket: ["wss://optimism-mainnet.infura.io/ws/v3"]),
                    privy: .init(http: ["https://optimism-mainnet.rpc.privy.systems"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Etherscan", url: "https://optimistic.etherscan.io"),
                    default: .init(name: "Optimism Explorer", url: "https://explorer.optimism.io")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 4286263)
                )
            )
        case .matic:
            ChainInfo(
                id: 137,
                name: "Polygon",
                network: "matic",
                nativeCurrency: .init(name: "MATIC", symbol: "MATIC", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://polygon-rpc.com"]),
                    public: .init(http: ["https://polygon-rpc.com"]),
                    alchemy: .init(http: ["https://polygon-mainnet.g.alchemy.com/v2"], webSocket: ["wss://polygon-mainnet.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://polygon-mainnet.infura.io/v3"], webSocket: ["wss://polygon-mainnet.infura.io/ws/v3"]),
                    privy: .init(http: ["https://polygon-mainnet.rpc.privy.systems"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "PolygonScan", url: "https://polygonscan.com"),
                    default: .init(name: "PolygonScan", url: "https://polygonscan.com")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 25770160)
                )
            )
        case .filecoinMainnet:
            ChainInfo(
                id: 314,
                name: "Filecoin Mainnet",
                network: "filecoin-mainnet",
                nativeCurrency: .init(name: "filecoin", symbol: "FIL", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://api.node.glif.io/rpc/v1"]),
                    public: .init(http: ["https://api.node.glif.io/rpc/v1"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Filfox", url: "https://filfox.info/en")
                )
            )
        // TODO: deprecate
        case .optimismGoerli:
            ChainInfo(
                id: 420,
                name: "Optimism Goerli",
                network: "optimism-goerli",
                nativeCurrency: .init(name: "Goerli Ether", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://goerli.optimism.io"]),
                    public: .init(http: ["https://goerli.optimism.io"]),
                    alchemy: .init(http: ["https://opt-goerli.g.alchemy.com/v2"], webSocket: ["wss://opt-goerli.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://optimism-goerli.infura.io/v3"], webSocket: ["wss://optimism-goerli.infura.io/ws/v3"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Etherscan", url: "https://goerli-optimism.etherscan.io"),
                    default: .init(name: "Etherscan", url: "https://goerli-optimism.etherscan.io")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 49461)
                )
            )
        case .arbitrum:
            ChainInfo(
                id: 42161,
                name: "Arbitrum One",
                network: "arbitrum",
                nativeCurrency: .init(name: "Ether", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://arb1.arbitrum.io/rpc"]),
                    public: .init(http: ["https://arb1.arbitrum.io/rpc"]),
                    alchemy: .init(http: ["https://arb-mainnet.g.alchemy.com/v2"], webSocket: ["wss://arb-mainnet.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://arbitrum-mainnet.infura.io/v3"], webSocket: ["wss://arbitrum-mainnet.infura.io/ws/v3"]),
                    privy: .init(http: ["https://arbitrum-mainnet.rpc.privy.systems"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Arbiscan", url: "https://arbiscan.io"),
                    default: .init(name: "Arbiscan", url: "https://arbiscan.io")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 7654707)
                )
            )
        case .celo:
            ChainInfo(
                id: 42220,
                name: "Celo",
                network: "celo",
                nativeCurrency: .init(name: "CELO", symbol: "CELO", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://forno.celo.org"]),
                    public: .init(http: ["https://forno.celo.org"]),
                    infura: .init(http: ["https://celo-mainnet.infura.io/v3"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "CeloScan", url: "https://celoscan.io"),
                    default: .init(name: "Celo Explorer", url: "https://explorer.celo.org/mainnet")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xcA11bde05977b3631167028862bE2a173976CA11", blockCreated: 13112599)
                )
            )
        case .celoAlfajores:
            ChainInfo(
                id: 44787,
                name: "Alfajores",
                network: "celo-alfajores",
                nativeCurrency: .init(name: "CELO", symbol: "A-CELO", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://alfajores-forno.celo-testnet.org"]),
                    public: .init(http: ["https://alfajores-forno.celo-testnet.org"]),
                    infura: .init(http: ["https://celo-alfajores.infura.io/v3"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "CeloScan", url: "https://alfajores.celoscan.io/"),
                    default: .init(name: "Celo Explorer", url: "https://explorer.celo.org/alfajores")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xcA11bde05977b3631167028862bE2a173976CA11", blockCreated: 14569001)
                ),
                testnet: true
            )
        case .avalancheFuji:
            ChainInfo(
                id: 43113,
                name: "Avalanche Fuji",
                network: "avalanche-fuji",
                nativeCurrency: .init(name: "Avalanche Fuji", symbol: "AVAX", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://api.avax-test.network/ext/bc/C/rpc"]),
                    public: .init(http: ["https://api.avax-test.network/ext/bc/C/rpc"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "SnowTrace", url: "https://testnet.snowtrace.io"),
                    default: .init(name: "SnowTrace", url: "https://testnet.snowtrace.io")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 7096959)
                )
            )
        case .avalanche:
            ChainInfo(
                id: 43114,
                name: "Avalanche",
                network: "avalanche",
                nativeCurrency: .init(name: "Avalanche", symbol: "AVAX", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://api.avax.network/ext/bc/C/rpc"]),
                    public: .init(http: ["https://api.avax.network/ext/bc/C/rpc"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "SnowTrace", url: "https://snowtrace.io"),
                    default: .init(name: "SnowTrace", url: "https://snowtrace.io")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 11907934)
                )
            )
        case .lineaTestnet:
            ChainInfo(
                id: 59140,
                name: "Linea Goerli Testnet",
                network: "linea-testnet",
                nativeCurrency: .init(name: "Linea Ether", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://rpc.goerli.linea.build"], webSocket: ["wss://rpc.goerli.linea.build"]),
                    public: .init(http: ["https://rpc.goerli.linea.build"], webSocket: ["wss://rpc.goerli.linea.build"]),
                    infura: .init(http: ["https://linea-goerli.infura.io/v3"], webSocket: ["wss://linea-goerli.infura.io/ws/v3"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Etherscan", url: "https://goerli.lineascan.build"),
                    default: .init(name: "Etherscan", url: "https://goerli.lineascan.build"),
                    filscan: .init(name: "Blockscout", url: "https://explorer.goerli.linea.build")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 498623)
                ),
                testnet: true
            )
        case .lineaMainnet:
            ChainInfo(
                id: 59144,
                name: "Linea Mainnet",
                network: "linea-mainnet",
                nativeCurrency: .init(name: "Linea Ether", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://rpc.linea.build"], webSocket: ["wss://rpc.linea.build"]),
                    public: .init(http: ["https://rpc.linea.build"], webSocket: ["wss://rpc.linea.build"]),
                    infura: .init(http: ["https://linea-mainnet.infura.io/v3"], webSocket: ["wss://linea-mainnet.infura.io/ws/v3"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Etherscan", url: "https://lineascan.build"),
                    default: .init(name: "Etherscan", url: "https://lineascan.build"),
                    filscan: .init(name: "Blockscout", url: "https://explorer.linea.build")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xcA11bde05977b3631167028862bE2a173976CA11", blockCreated: 42)
                ),
                testnet: false
            )
        // TODO: deprecate
        case .polygonMumbai:
            ChainInfo(
                id: 80001,
                name: "Polygon Mumbai",
                network: "maticmum",
                nativeCurrency: .init(name: "MATIC", symbol: "MATIC", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://matic-mumbai.chainstacklabs.com"]),
                    public: .init(http: ["https://matic-mumbai.chainstacklabs.com"]),
                    alchemy: .init(http: ["https://polygon-mumbai.g.alchemy.com/v2"], webSocket: ["wss://polygon-mumbai.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://polygon-mumbai.infura.io/v3"], webSocket: ["wss://polygon-mumbai.infura.io/ws/v3"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "PolygonScan", url: "https://mumbai.polygonscan.com"),
                    default: .init(name: "PolygonScan", url: "https://mumbai.polygonscan.com")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 25770160)
                ),
                testnet: true
            )
        case .filecoinCalibration:
            ChainInfo(
                id: 314159,
                name: "Filecoin Calibration",
                network: "filecoin-calibration",
                nativeCurrency: .init(name: "testnet filecoin", symbol: "tFIL", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://api.calibration.node.glif.io/rpc/v1"]),
                    public: .init(http: ["https://api.calibration.node.glif.io/rpc/v1"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Filscan", url: "https://calibration.filscan.io"),
                    default: .init(name: "Filscan", url: "https://calibration.filscan.io")
                )
            )
        // TODO: deprecate
        case .arbitrumGoerli:
            ChainInfo(
                id: 421613,
                name: "Arbitrum Goerli",
                network: "arbitrum-goerli",
                nativeCurrency: .init(name: "Arbitrum Goerli Ether", symbol: "ETH", decimals: 18),
                rpcUrls: .init(
                    default: .init(http: ["https://goerli-rollup.arbitrum.io/rpc"]),
                    public: .init(http: ["https://goerli-rollup.arbitrum.io/rpc"]),
                    alchemy: .init(http: ["https://arb-goerli.g.alchemy.com/v2"], webSocket: ["wss://arb-goerli.g.alchemy.com/v2"]),
                    infura: .init(http: ["https://arbitrum-goerli.infura.io/v3"], webSocket: ["wss://arbitrum-goerli.infura.io/ws/v3"])
                ),
                blockExplorers: .init(
                    etherscan: .init(name: "Arbiscan", url: "https://goerli.arbiscan.io/"),
                    default: .init(name: "Arbiscan", url: "https://goerli.arbiscan.io/")
                ),
                contracts: .init(
                    multicall3: .init(address: "0xca11bde05977b3631167028862be2a173976ca11", blockCreated: 88114)
                ),
                testnet: true
            )
        }
    }
}
