import Foundation

internal enum PrivyEventType: String, Codable, Sendable {
    case ready = "privy:iframe:ready"
    case createEthereumWallet = "privy:wallet:create"
    case createSolanaWallet = "privy:solana-wallet:create"
    case createAdditional = "privy:wallets:add"
    case connect = "privy:wallets:connect"
    case recover = "privy:wallets:recover"
    case rpc = "privy:wallets:rpc"
    case setPassword = "privy:wallet:set-recovery-password"
    case signWithUserSigner = "privy:user-signer:sign"
    case delegatedActionsConsent = "privy:delegated-actions:consent"
    case setMfaToken = "privy:mfa:set-token"
    case clearMfa = "privy:mfa:clear"
}
