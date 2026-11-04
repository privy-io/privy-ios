import Foundation

/// `URLProtocol` that answers every request made through `URLSession.shared` with a canned response,
/// recording the requests it sees. `URLRequest.execute()` talks to `URLSession.shared` directly, so this
/// is the seam for testing repositories at the network boundary without hitting the network.
///
/// Call `StubURLProtocol.install()` in `setUp` and `uninstall()` in `tearDown`.
internal final class StubURLProtocol: URLProtocol {
    internal struct Stub {
        internal var statusCode: Int
        internal var body: Data
        internal var error: Error?

        internal static func json(_ json: String, statusCode: Int = 200) -> Stub {
            Stub(statusCode: statusCode, body: Data(json.utf8), error: nil)
        }

        internal static func failure(_ error: Error) -> Stub {
            Stub(statusCode: 0, body: Data(), error: error)
        }
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var stub = Stub.json("{}")
    private nonisolated(unsafe) static var recordedRequests: [URLRequest] = []

    /// The response served to the next request(s).
    internal static var nextStub: Stub {
        get { lock.withLock { stub } }
        set { lock.withLock { stub = newValue } }
    }

    /// Requests received since `install()`, with `httpBody` populated.
    internal static var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    internal static func install() {
        lock.withLock {
            stub = .json("{}")
            recordedRequests = []
        }
        URLProtocol.registerClass(StubURLProtocol.self)
    }

    internal static func uninstall() {
        URLProtocol.unregisterClass(StubURLProtocol.self)
    }

    override internal class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override internal class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override internal func startLoading() {
        var recorded = request
        // The body of a request is delivered as a stream by the time it reaches a URLProtocol.
        if recorded.httpBody == nil, let stream = request.httpBodyStream {
            recorded.httpBody = Self.read(stream)
        }
        Self.lock.withLock { Self.recordedRequests.append(recorded) }

        let stub = Self.nextStub
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        // swiftlint:disable:next force_unwrapping
        let url = request.url!
        let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override internal func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
