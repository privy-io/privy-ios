import Foundation
internal import FactoryKit

extension PrivyContainer {
    internal var ongoingMfaManager: Factory<PrivyOngoingMFAManager> {
        self { PrivyOngoingMFAManager() }.singleton
    }
}

/// Manages ongoing MFA verification continuations.
///
/// When an operation fails with MFA required and a delegate is set, a continuation
/// is created and stored here. When any MFA verification succeeds, all stored
/// continuations are resolved.
internal actor PrivyOngoingMFAManager {
    private let logger: Logger = resolve(\PrivyContainer.logger)
    private var pendingVerifications: [UUID: CheckedContinuation<Void, Error>] = [:]

    /// The current MFA configuration, resolved fresh each time to pick up runtime updates.
    private var mfaConfig: PrivyMFAConfig {
        resolve(\PrivyContainer.mfaConfig)
    }

    /// The configured MFA timeout.
    private var mfaTimeout: Duration {
        mfaConfig.mfaTimeout
    }

    /// Adds a continuation to await MFA verification.
    ///
    /// - Returns: A unique identifier for this pending verification.
    internal func addPending(_ continuation: CheckedContinuation<Void, Error>) -> UUID {
        let id = UUID()
        pendingVerifications[id] = continuation
        return id
    }

    /// Removes a pending verification (for cleanup on cancellation or error).
    internal func removePending(id: UUID) {
        pendingVerifications.removeValue(forKey: id)
    }

    /// Resolves all pending MFA verifications.
    ///
    /// Called when any MFA verification method succeeds or when MFA verification is cancelled.
    ///
    /// - Parameters:
    ///   - error: If provided, all continuations will throw this error. Otherwise, they resume successfully.
    internal func resolveAll(throwing error: Error? = nil) {
        let ids = pendingVerifications.keys.map { $0.uuidString }
        logger.verboseInternal("MFA resolveAll called (pending=\(pendingVerifications.count), ids=\(ids), hasError=\(error != nil))")
        for (_, continuation) in pendingVerifications {
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
        pendingVerifications.removeAll()
    }
}

// MARK: MFA handling scope

internal extension PrivyOngoingMFAManager {
    /// A closure that potentially throws when MFA verification is needed.
    ///
    /// The error thrown must be `PrivyError(.embeddedWalletFailure(reason: .missingOrInvalidMfa))`
    /// or `PrivyError(.embeddedWalletFailure(reason: .mfaChallengeExpired))` to trigger validation.
    typealias MFAProtectedClosure<T: Sendable> = @Sendable (_: String?) async throws -> T

    /// Executes an operation, handling MFA verification if needed.
    ///
    /// When the operation throws `PrivyError(.embeddedWalletFailure(reason: .missingOrInvalidMfa))`
    /// or `PrivyError(.embeddedWalletFailure(reason: .mfaChallengeExpired))`,
    /// this method will prompt the user for MFA via the configured delegate and retry the operation.
    ///
    /// - Parameters:
    ///   - operation: The async operation to execute, which receives the current MFA token.
    ///
    /// - Returns: The result of the operation.
    ///
    /// - Throws:
    ///   - `PrivyError(.embeddedWalletFailure(reason: .timeoutOnMfa))` if the delegate is prompted but not unblocked
    ///   - Propagates errors thrown by `operation`
    func withMfaHandling<T: Sendable>(operation: MFAProtectedClosure<T>) async throws -> T {
        // Resolved on-demand to avoid dependency cycles
        let mfaTokenRepository = resolve(\PrivyContainer.mfaTokenRepository)
        let mfaToken = await mfaTokenRepository.retrieve()

        do {
            return try await operation(mfaToken)
        } catch {
            // Map the error to standard MFA errors first
            let error = mapErrorIfMfa(error)

            // We only need to handle 'mfa needed' errors
            guard let privyError = error as? PrivyError, privyError.meansMfaNeeded() else {
                throw error
            }

            // Not having a delegate set means the developer chooses to handle this themselves
            guard let delegate = mfaConfig.delegate else {
                throw error
            }

            let user = PrivyContainer.shared.privyUser()

            logger.verboseInternal("MFA required — creating continuation (timeout=\(mfaTimeout))")
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let pendingId = self.addPending(continuation)
                logger.verboseInternal("MFA continuation added (id=\(pendingId))")

                // Start timeout task
                Task {
                    let timeout = self.mfaTimeout
                    let timeoutSeconds = timeout / .seconds(1)
                    self.logger.verboseInternal("MFA timeout task starting (sleeping for \(timeoutSeconds)s, id=\(pendingId))")
                    try await Task.sleep(for: timeout)
                    self.logger.verboseInternal("MFA timeout task woke up after sleep (id=\(pendingId))")
                    self.handleTimeout(pendingId: pendingId)
                }

                // Fire-and-forget: notify the delegate but don't await
                Task {
                    await delegate.onMfaRequired(for: user)
                }
            }

            // After MFA prompt succeeds, get fresh token and retry
            let newMfaToken = await mfaTokenRepository.retrieve()
            do {
                return try await operation(newMfaToken)
            } catch {
                // Map to the standard MFA error form if needed
                throw mapErrorIfMfa(error)
            }
        }
    }

    /// Handles MFA timeout by resuming the continuation with a timeout error.
    private func handleTimeout(pendingId: UUID) {
        guard let continuation = pendingVerifications.removeValue(forKey: pendingId) else {
            logger.verboseInternal("MFA timeout fired but continuation already resolved (id=\(pendingId))")
            return
        }
        logger.verboseInternal("MFA timeout firing — resolving continuation with timeoutOnMfa (id=\(pendingId))")
        continuation.resume(throwing: PrivyError(.embeddedWalletFailure(reason: .timeoutOnMfa)))
    }
}

fileprivate extension PrivyError {
    func meansMfaNeeded() -> Bool {
        switch self.errorCode {
        case .embeddedWalletFailure(reason: .missingOrInvalidMfa),
             .embeddedWalletFailure(reason: .mfaChallengeExpired):
            return true
        default:
            return false
        }
    }
}

fileprivate let MFA_ERROR_CODE_MAPPING: [String: PrivyErrorCode.EmbeddedWalletFailureReason] = [
    "missing_or_invalid_mfa": .missingOrInvalidMfa,
    "expired_or_invalid_mfa_token": .mfaChallengeExpired,
    "mfa_timeout": .timeoutOnMfa,
    "mfa_verification_max_attempts_reached": .mfaVerificationMaxAttemptsReached,
]

internal func mapErrorIfMfa(_ error: any Error) -> any Error {
    // Maps API errors based on the error code
    if case ApiError.apiError(_, let errorCode, _) = error,
       let reason = MFA_ERROR_CODE_MAPPING[errorCode] {
        return PrivyError(.embeddedWalletFailure(reason: reason))
    }

    // Maps iframe errors based on the error type
    if let privyError = error as? PrivyError,
       case .embeddedWalletFailure(reason: .iframeError(type: let iframeType, message: _)) = privyError.errorCode,
       let reason = MFA_ERROR_CODE_MAPPING[iframeType] {
        return PrivyError(.embeddedWalletFailure(reason: reason))
    }

    // Other errors are left as-is.
    return error
}
