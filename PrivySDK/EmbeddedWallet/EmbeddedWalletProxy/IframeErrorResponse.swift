import Foundation

internal struct IframeErrorResponse: Codable {
    internal let id: String
    internal let event: PrivyEventType
    internal let error: ErrorData
}

internal extension IframeErrorResponse {
    init(str: String) throws {
        guard let data = str.data(using: .utf8) else {
            throw PrivyError(.embeddedWalletFailure(reason: .failedToDecodeWalletResponse))
        }
        guard let value = try? JSONDecoder().decode(Self.self, from: data) else {
            throw PrivyError(.embeddedWalletFailure(reason: .failedToDecodeWalletResponse))
        }
        self = value
    }
}

// MARK: - Errors

internal struct ErrorData: Codable {
    internal let type: String
    internal let message: String
}
