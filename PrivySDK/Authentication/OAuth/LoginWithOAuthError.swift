import Foundation

internal enum LoginWithOAuthError: LocalizedError {
    case authenticationError(String)

    internal var errorDescription: String? {
        switch self {
        case .authenticationError(let description):
            description
        }
    }
}
