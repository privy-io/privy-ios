import Foundation
internal import FactoryKit

internal extension URLRequest {
    func execute<T: Decodable>() async throws -> T {
        #if DEBUG
            let logger = PrivyContainer.shared.logger()
            let method = httpMethod ?? "?"
            let urlString = url?.absoluteString ?? "?"
            let bodyString = httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "(empty)"
            let headerString = (allHTTPHeaderFields ?? [:])
                .sorted(by: { $0.key < $1.key })
                .map { "  \($0.key): \($0.value)" }
                .joined(separator: "\n")

            logger.verboseInternal("""

            ──▶ REQUEST \(method) \(urlString)
            Headers:
            \(headerString)
            Body: \(bodyString)
            ──▶ END REQUEST
            """)
        #endif
        // Send HTTP request
        let (data, response) = try await URLSession.shared.data(for: self)

        guard let response = response as? HTTPURLResponse else {
            throw ApiError.malformedResponse
        }

        #if DEBUG
            let responseBody = String(data: data, encoding: .utf8) ?? "(non-utf8)"
            logger.verboseInternal("""

            ◀── RESPONSE \(response.statusCode) \(url?.absoluteString ?? "?")
            Body: \(responseBody)
            ◀── END RESPONSE
            """)
        #endif

        // Check if response code is between 200 and 299
        guard isSuccessStatusCode(response.statusCode) else {
            // If not, http error. Try decoding response body as Privy error type
            if let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                // Give domain-specific interceptors (e.g. Authentication) a chance to translate
                // this backend error code into a more specific typed error before falling back
                // to the generic ApiError below.
                try resolve(\PrivyContainer.backendErrorInterceptor).intercept(code: backendError.code, responseData: data)
                throw ApiError.apiError(httpCode: response.statusCode, errorCode: backendError.code, description: backendError.error)
            } else {
                throw ApiError.networkError(responseCode: response.statusCode, description: "Network Error")
            }
        }

        do {
            // Decode response
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiError.decodingError(error)
        }
    }

    private func isSuccessStatusCode(_ statusCode: Int) -> Bool {
        let successRange = 200 ..< 300
        return successRange.contains(statusCode)
    }
}

internal struct BackendErrorResponse: Decodable {
    internal let error: String
    internal let code: String
}

/// Hook allowing domain layers (e.g. Authentication) to translate a backend error code, using the raw
/// response body, into a more specific typed error. Implementations that don't recognize `code` should
/// return without throwing so the generic `ApiError.apiError` is thrown instead. Keeps this networking
/// extension agnostic of any particular domain's error shapes.
internal protocol BackendErrorInterceptor: Sendable {
    func intercept(code: String, responseData: Data) throws
}

internal struct EmptyResponse: Decodable {}
