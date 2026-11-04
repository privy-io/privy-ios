import Foundation

internal extension URLError.Code {
    /// Represents whether the error code means no connection could be established, either because no internet is available
    /// or because the server was otherwise unavailable.
    var isConnectivityError: Bool {
        switch self {
        case .timedOut,
             .networkConnectionLost,
             .notConnectedToInternet,
             .cannotConnectToHost,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
}
