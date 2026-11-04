import Foundation
@testable import PrivySDK

/// `NetworkService` test double that builds requests against a fixed host without touching config or
/// the client-analytics-id repository. Pair with `StubURLProtocol` to answer them.
internal final class TestNetworkService: NetworkService, @unchecked Sendable {
    internal struct MakeRequestCall: Equatable {
        internal let path: String
        internal let token: String?
        internal let httpMethod: String
    }

    internal var makeRequestError: Error?
    internal private(set) var makeRequestCalls: [MakeRequestCall] = []

    internal func makeRequest(path: String, token: String?, httpMethod: String, queryItems: [URLQueryItem]?) async throws -> URLRequest {
        makeRequestCalls.append(MakeRequestCall(path: path, token: token, httpMethod: httpMethod))
        if let makeRequestError { throw makeRequestError }

        // swiftlint:disable:next force_unwrapping
        var request = URLRequest(url: URL(string: "https://auth.test.privy.io\(path)")!)
        request.httpMethod = httpMethod
        token.map { request.setValue("Bearer \($0)", forHTTPHeaderField: "Authorization") }
        return request
    }
}
