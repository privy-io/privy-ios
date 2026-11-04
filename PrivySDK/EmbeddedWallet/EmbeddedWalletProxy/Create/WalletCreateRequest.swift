import Foundation

// MARK: - Create Ethereum Wallet Request

internal struct CreateEthereumWalletRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .createEthereumWallet
    internal let data: CreateEthereumWalletRequestData
}

internal struct CreateEthereumWalletRequestData: Codable {
    internal let accessToken: String

    /* The address of the user's existing Solana embedded wallet.
     *
     * If an existing address is passed, the iframe will re-assemble the entropy for the existing address to derive the Ethereum wallet.
     * If no existing address is passed, the iframe will generate new entropy for the Ethereum wallet.
     */
    internal let solanaAddress: String?
}

// MARK: - Create Solana Wallet Request

internal struct CreateSolanaWalletRequest: PrivyIframeRequest {
    internal let id: String
    internal private(set) var event: PrivyEventType = .createSolanaWallet
    internal let data: CreateSolanaWalletRequestData
}

internal struct CreateSolanaWalletRequestData: Codable {
    internal let accessToken: String

    /* The address of the user's existing Ethereum embedded wallet.
     *
     * If an existing address is passed, the iframe will re-assemble the entropy for the existing address to derive the Solana wallet.
     * If no existing address is passed, the iframe will generate new entropy for the Solana wallet.
     */
    internal let ethereumAddress: String?
}
