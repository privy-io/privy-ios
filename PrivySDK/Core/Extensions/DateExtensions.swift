import Foundation

internal extension Date {
    func toISO8601() -> String {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.string(from: self)
    }
}
