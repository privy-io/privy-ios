import Foundation

/// An account linked to the active user
public enum LinkedAccount: Sendable {
    /// An account created with a custom auth provider
    case customAuth(CustomAuth)
    /// An embedded ethereum wallet account
    case embeddedEthereumWallet(EmbeddedEthereumWalletAccount)
    /// An embedded solana wallet account
    case embeddedSolanaWallet(EmbeddedSolanaWalletAccount)
    /// An external wallet account
    case externalWallet(ExternalWallet)
    /// An email account
    case email(EmailAccount)
    /// A phone number account
    case phone(PhoneNumberAccount)
    /// A Google account created via Google Sign-In
    case google(GoogleAccount)
    /// A Twitter account via Login with X
    case twitter(TwitterAccount)
    /// An Apple account created via Sign in with Apple
    case apple(AppleAccount)
    /// A Discord account created via Login with Discord
    case discord(DiscordAccount)
    /// A Telegram account created via Login with Telegram
    case telegram(TelegramAccount)
    /// A passkey
    case passkey(PasskeyAccount)
}

internal extension [LinkedAccount] {
    /// Retrieves the user's primary wallet with the following priority: eth -> solana
    /// This info is typically used to pass entropy information into an embedded wallet iFrame request
    /// - Throws: `PrivyError` if there is no primary embedded wallet account
    func getPrimaryWalletForEntropyInfo() throws -> any EmbeddedWalletAccount {
        if let primaryEthWallet = getPrimaryEmbeddedEthereumWalletAccount() {
            return primaryEthWallet
        }
        if let primarySolWallet = getPrimaryEmbeddedSolanaWalletAccount() {
            return primarySolWallet
        }
        throw PrivyError(.embeddedWalletFailure(reason: .noWalletAvailable))
    }

    func hasWalletOf(chainType: ChainType) -> Bool {
        return getPrimaryWallet(chainType: chainType) != nil
    }

    func getPrimaryWallet(chainType: ChainType) -> (any EmbeddedWalletAccount)? {
        switch chainType {
        case .ethereum:
            getPrimaryEmbeddedEthereumWalletAccount()
        case .solana:
            getPrimaryEmbeddedSolanaWalletAccount()
        }
    }

    func getEmbeddedWalletAccounts(chainType: ChainType) -> [(any EmbeddedWalletAccount)] {
        switch chainType {
        case .ethereum:
            getEmbeddedEthereumWalletAccounts()
        case .solana:
            getEmbeddedSolanaWalletAccounts()
        }
    }

    func getEmbeddedWalletAccountByAddress(address: String) -> (any EmbeddedWalletAccount)? {
        getEmbeddedEthereumWalletAccounts().first { $0.address == address }
            ?? getEmbeddedSolanaWalletAccounts().first { $0.address == address }
    }

    func getEmbeddedWalletAccount(id: String) -> (any EmbeddedWalletAccount)? {
        getEmbeddedEthereumWalletAccounts().first { $0.id == id }
            ?? getEmbeddedSolanaWalletAccounts().first { $0.id == id }
    }

    func getPrimaryEmbeddedEthereumWalletAccount() -> EmbeddedEthereumWalletAccount? {
        getEmbeddedEthereumWalletAccounts().first { $0.hdWalletIndex == 0 && !$0.imported }
    }

    func getPrimaryEmbeddedSolanaWalletAccount() -> EmbeddedSolanaWalletAccount? {
        getEmbeddedSolanaWalletAccounts().first { $0.hdWalletIndex == 0 && !$0.imported }
    }

    private func getEmbeddedEthereumWalletAccounts() -> [EmbeddedEthereumWalletAccount] {
        self.compactMap { account in
            guard case let .embeddedEthereumWallet(account) = account else { return nil }
            return account
        }
    }

    private func getEmbeddedSolanaWalletAccounts() -> [EmbeddedSolanaWalletAccount] {
        self.compactMap { account in
            guard case let .embeddedSolanaWallet(account) = account else { return nil }
            return account
        }
    }

    func getEmailAccount() -> EmailAccount? {
        for account in self {
            if case let .email(account) = account {
                return account
            }
        }
        return nil
    }

    func getPhoneAccount() -> PhoneNumberAccount? {
        for account in self {
            if case let .phone(account) = account {
                return account
            }
        }
        return nil
    }
}

internal extension LinkedAccountResponse {
    func toLinkedAccountOrNull() -> LinkedAccount? {
        switch self {
        case .customAuth(let customAuthAccountResponse):
            .customAuth(customAuthAccountResponse.toCustomAuth())
        case .wallet(let walletAccountResponse):
            walletAccountResponse.toWalletAccount()
        case .email(let emailAccountResponse):
            .email(emailAccountResponse.toEmailAccount())
        case .phone(let phoneNumberAccountResponse):
            .phone(phoneNumberAccountResponse.toPhoneNumberAccount())
        case .google(let googleOAuthAccountResponse):
            .google(googleOAuthAccountResponse.toGoogleAccount())
        case .discord(let discordOAuthAccountResponse):
            .discord(discordOAuthAccountResponse.toDiscordAccount())
        case .twitter(let twitterOAuthAccountResponse):
            .twitter(twitterOAuthAccountResponse.toTwitterAccount())
        case .apple(let appleOAuthAccountResponse):
            .apple(appleOAuthAccountResponse.toAppleAccount())
        case .telegram(let telegramOAuthAccountResponse):
            .telegram(telegramOAuthAccountResponse.toTelegramAccount())
        case .passkey(let passkeyResponse):
            .passkey(passkeyResponse.toPasskeyAccount())
        case .unknown:
            nil
        }
    }
}

private extension WalletAccountResponse {
    func toWalletAccount() -> LinkedAccount {
        guard isPrivyWallet() else {
            return .externalWallet(toExternalWallet())
        }

        switch ChainType(chainType: chainType) {
        case .solana:
            return .embeddedSolanaWallet(toEmbeddedSolanaWalletAccount())
        case .ethereum:
            return .embeddedEthereumWallet(toEmbeddedEthereumWalletAccount())
        }
    }
}
