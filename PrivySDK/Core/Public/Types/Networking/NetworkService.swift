import Foundation
internal import FactoryKit

public enum ApiError: LocalizedError {
    case couldNotConstructRequest
    case decodingError(Error)
    case apiError(httpCode: Int, errorCode: String, description: String)
    case networkError(responseCode: Int, description: String? = nil)
    case malformedResponse

    public var errorDescription: String? {
        switch self {
        case .couldNotConstructRequest:
            return "Api request could not be contructed"
        case .decodingError(let err):
            return "Error decoding api response \(err)"
        case .apiError(let httpCode, let errorCode, let description):
            return "Received \(httpCode) response, '\(errorCode)' API error: \(description)"
        case .networkError(let code, let description):
            let descriptionText = description ?? ""
            return "Expected status code 200 but got \(code) \(descriptionText)"
        case .malformedResponse:
            return "Received a request body that could not be read"
        }
    }
}

internal protocol NetworkService: Sendable {
    /// Creates a request from the given path, prepared with the right headers for calling the Privy API.
    /// - Returns a URLRequest struct
    ///  - Throws `ApiError.couldNotConstructRequest` if the URL cannot be built from the given path
    func makeRequest(path: String, token: String?, httpMethod: String, queryItems: [URLQueryItem]?) async throws -> URLRequest
}

extension NetworkService {
    internal func makeRequest(path: String, token: String?) async throws -> URLRequest {
        try await makeRequest(path: path, token: token, httpMethod: "POST", queryItems: nil)
    }

    internal func makeRequest(path: String, token: String?, httpMethod: String) async throws -> URLRequest {
        try await makeRequest(path: path, token: token, httpMethod: httpMethod, queryItems: nil)
    }
}

extension PrivyContainer {
    internal var networkService: Factory<NetworkService> {
        self { NetworkServiceImpl() }.shared
    }
}

/// Gets the current SDK version as a string for setting HTTP headers for Privy
private func getIosSdkVersion() -> String {
    return if let info = Bundle(for: NetworkServiceImpl.self).infoDictionary,
              let currentVersion = info["CFBundleShortVersionString"] as? String {
        currentVersion
    } else {
        "unknown"
    }
}

private final class NetworkServiceImpl: NetworkService {
    private let config: PrivyConfig = resolve(\PrivyContainer.config)
    private let caidRepository: ClientAnalyticsIdRepository = resolve(\PrivyContainer.caidRepository)

    internal func makeRequest(path: String, token: String?, httpMethod: String, queryItems: [URLQueryItem]?) async throws -> URLRequest {
        let urlString = "\(config.baseUrl)\(path)"

        let url: URL
        if let queryItems, !queryItems.isEmpty {
            guard var components = URLComponents(string: urlString) else {
                throw ApiError.couldNotConstructRequest
            }
            components.queryItems = queryItems
            guard let constructedUrl = components.url else {
                throw ApiError.couldNotConstructRequest
            }
            url = constructedUrl
        } else {
            guard let simpleUrl = URL(string: urlString) else {
                throw ApiError.couldNotConstructRequest
            }
            url = simpleUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "x-native-app-identifier")

        token.map {
            request.setValue("Bearer \($0)", forHTTPHeaderField: "Authorization")
        }

        request.setValue(config.appId, forHTTPHeaderField: "privy-app-id")

        config.appClientId.map {
            request.setValue($0, forHTTPHeaderField: "privy-client-id")
        }

        let sdkPlatformAndVersion = if let internalSettingsOverride = PrivyInternal.settings {
            // Consumer of this SDK overrode platform and version
            "\(internalSettingsOverride.platform)-swift:\(internalSettingsOverride.sdkVersion)"
        } else {
            "swift:\(getIosSdkVersion())"
        }

        request.setValue(sdkPlatformAndVersion, forHTTPHeaderField: "privy-client")

        request.setValue(await caidRepository.loadClientId(), forHTTPHeaderField: "privy-ca-id")

        return request
    }
}
