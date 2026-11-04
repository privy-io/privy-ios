import Foundation

// MARK: Ethereum

internal struct CreateEthereumWalletResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .createEthereumWallet
    internal let data: CreateEthereumWalletResponseData
}

internal struct CreateEthereumWalletResponseData: Codable {
    public let address: String
}

// MARK: Solana

internal struct CreateSolanaWalletResponse: PrivyIframeResponse {
    internal let id: String
    internal private(set) var event: PrivyEventType = .createSolanaWallet
    internal let data: CreateSolanaWalletResponseData
}

internal struct CreateSolanaWalletResponseData: Codable {
    public let publicKey: String
}
