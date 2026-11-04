import Foundation

/// A wrapper  type for a "seconds since epoch" `TimeInterval`, convertible into a `Date`
internal struct SecondsSinceEpoch: Decodable {
    private var secondsSinceEpoch: TimeInterval

    internal var date: Date {
        Date(timeIntervalSince1970: self.secondsSinceEpoch)
    }

    internal init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.secondsSinceEpoch = try container.decode(TimeInterval.self)
    }
}
