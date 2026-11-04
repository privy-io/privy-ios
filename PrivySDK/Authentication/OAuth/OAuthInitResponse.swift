import Foundation

internal struct OAuthInitResponse: Decodable {
    internal let url: String

    private enum CodingKeys: String, CodingKey {
        case url
    }
}
