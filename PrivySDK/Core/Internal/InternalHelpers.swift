import Foundation

internal extension String {
    func isInternalAppId() -> Bool {
        return !internalAppId.isEmpty && self == internalAppId
    }
}

// Demo app approved for diagnostic logging and staging endpoints.
// Populated via an environment variable so this id doesn't need to live in public source.
// The test app only ever runs as one app ID per process (on-device vs. TEE stack), so a
// single var covers both cases — point it at whichever app ID you're currently running.
private let internalAppId = ProcessInfo.processInfo.environment["PRIVY_INTERNAL_APP_ID"] ?? ""
