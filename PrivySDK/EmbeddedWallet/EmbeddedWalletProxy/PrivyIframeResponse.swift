import Foundation

internal protocol PrivyIframeResponse: Decodable, Sendable {
    associatedtype T: Decodable, Sendable

    var id: String { get }
    var event: PrivyEventType { get }
    var data: T { get }
}

internal extension PrivyIframeResponse {
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
