import Foundation

// MARK: - Interfaces

internal protocol PrivyIframeRequest: Encodable, Sendable {
    associatedtype T: Encodable

    var id: String { get }
    var event: PrivyEventType { get }
    var data: T { get }
}

internal extension PrivyIframeRequest {
    var stringData: String? {
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }

        guard let value = String(data: data, encoding: String.Encoding.utf8) else {
            return nil
        }
        return value
    }
}
