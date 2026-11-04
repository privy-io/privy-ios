import Foundation
@preconcurrency import Combine
internal import FactoryKit

extension PrivyContainer {
    internal var privyReadyStateHandler: Factory<PrivyReadyStateHandler> {
        self { PrivyReadyStateHandlerImpl() }.shared
    }
}

internal protocol PrivyReadyStateHandler: Sendable {
    func awaitReady() async
}

/// A class that internally managed Privy ready state
/// Privy is considered to be ready after auth state has been set to anything other than notReady
private final class PrivyReadyStateHandlerImpl: PrivyReadyStateHandler {
    private let logger: Logger = resolve(\PrivyContainer.logger)
    private let internalAuthStateManager: InternalAuthStateManager = resolve(\PrivyContainer.internalAuthStateManager)

    // Value subject that holds the value of Privy ready state
    private let isReadySubject = CurrentValueSubject<Bool, Never>(false)

    init() {
        // As of today, we consider Privy ready after auth state has been set to a value other than "notReady"
        Task {
            for await authState in internalAuthStateManager.stateStream {
                // VERY IMPORTANT: This triggers Privy ready state to true
                if !self.isReady() && authState.isSet {
                    logger.debugInternal("Privy determined auth state has been set. Setting ready state to true.")
                    // Privy SDK is ready when auth state gets updated to something other than "notReady"
                    isReadySubject.send(true)
                }
            }
        }
    }

    func awaitReady() async {
        // If ready is already true, immediately return
        if isReady() {
            logger.debugInternal("Privy already ready")
            return
        }

        // If not, wait until isReadySubject fires true, then return
        for await isReady in isReadySubject.values {
            if isReady {
                logger.debugInternal("Received Privy ready state - returning from awaitReady")
                return
            }
        }
    }

    func isReady() -> Bool {
        return isReadySubject.value
    }
}

private extension InternalAuthState {
    // auth state is considered set if it is no longer "not ready"
    var isSet: Bool {
        get {
            if case .notReady = self {
                return false
            } else {
                return true
            }
        }
    }
}
