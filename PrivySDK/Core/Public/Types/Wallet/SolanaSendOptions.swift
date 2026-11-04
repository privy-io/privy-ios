import Foundation

/// Configuration options for sending a Solana transaction
public struct SolanaSendOptions: Sendable {
    /// Disable the transaction verification step
    public let skipPreflight: Bool?

    /// Preflight commitment level
    public let preflightCommitment: Commitment?

    /// Maximum number of times for the RPC node to retry sending the transaction to the leader.
    public let maxRetries: Int?

    /// The minimum slot that the request can be evaluated at
    public let minContextSlot: Int?

    public init(skipPreflight: Bool? = nil, preflightCommitment: Commitment? = nil, maxRetries: Int? = nil, minContextSlot: Int? = nil) {
        self.skipPreflight = skipPreflight
        self.preflightCommitment = preflightCommitment
        self.maxRetries = maxRetries
        self.minContextSlot = minContextSlot
    }

    /// The level of commitment desired when querying state
    public enum Commitment: String, Sendable {
        /// The highest slot of the heaviest fork processed by the node.
        case processed = "processed"
        /// The highest slot that has been voted on by supermajority of the cluster.
        case confirmed = "confirmed"
        /// The highest slot having reached max vote lockout, as recognized by a supermajority of the cluster.
        case finalized = "finalized"
        /// Prefer `.processed` instead.
        /// The highest slot of the heaviest fork.
        case recent = "recent"
        /// Prefer `.confirmed` instead.
        /// The highest slot having reached 1 confirmation by supermajority of the cluster.
        case single = "single"
        /// Prefer `.confirmed` instead.
        /// The highest slot that has been voted on by supermajority of the cluster.
        case singleGossip = "singleGossip"
        /// Prefer `.finalized` instead.
        /// The highest slot having reached max vote lockout.
        case root = "root"
        /// Prefer `.finalized` instead.
        /// The highest slot having reached max vote lockout, as recognized by a supermajority of the cluster.
        case max = "max"
    }
}
