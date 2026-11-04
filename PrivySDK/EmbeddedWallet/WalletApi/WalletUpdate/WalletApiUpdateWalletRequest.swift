import Foundation

// MARK: - PATCH /api/v1/wallets/{wallet_id} request body

internal struct WalletApiUpdateWalletRequest: Encodable {
    internal let additionalSigners: [AdditionalSignerParam]?

    private enum CodingKeys: String, CodingKey {
        case additionalSigners = "additional_signers"
    }
}
