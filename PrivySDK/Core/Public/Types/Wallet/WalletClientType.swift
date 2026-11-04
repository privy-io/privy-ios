import Foundation

public enum WalletClientType: String, Sendable {
    // To be used if no wallet clients below apply
    case other

    // privy wallet
    case privy

    // coinbase wallet
    case coinbase_wallet

    // wallet connect supported wallets
    case metamask
    case trust
    case safe
    case rainbow
    case uniswap
    case zerion
    case argent
    case spot
    case omni
    case cryptocom
    case blockchain
    case safepal
    case bitkeep
    case zengo
    case oneInch
    case binance
    case exodus
    case mew_wallet
    case alphawallet
    case keyring_pro
    case mathwallet
    case unstoppable
    case obvious
    case ambire
    case internet_money_wallet
    case coin98
    case abc_wallet
    case arculus_wallet
    case haha
    case cling_wallet
    case broearn
    case copiosa
    case burrito_wallet
    case enjin_wallet
    case plasma_wallet
    case avacus
    case bee
    case pitaka
    case pltwallet
    case minerva
    case kryptogo
    case prema
    case slingshot
    case kriptonio
    case timeless
    case secux
    case bitizen
    case blocto
    case safemoon
}
