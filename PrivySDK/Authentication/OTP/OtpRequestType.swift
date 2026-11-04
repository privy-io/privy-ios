import Foundation

internal enum OtpRequestType: Equatable {
    case email(email: String)
    case phone(_ phone: String)
}
