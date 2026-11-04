import Foundation

/// Input parameters for adding an additional signer to a wallet.
///
/// A signer represents a KeyQuorum that can authorize transactions on a wallet alongside the wallet owner.
public struct SignerInput: Sendable {
    /// The identifier of the signer to add (e.g. a KeyQuorum ID like "kq_abc123").
    public let signerId: String

    /// Optional list of policy IDs to override for this signer.
    /// If nil, the wallet's default policies apply to this signer.
    public let policyIds: [String]?

    /// Creates a new signer input.
    ///
    /// - Parameters:
    ///   - signerId: The identifier of the key quorum to add as a signer.
    ///   - policyIds: Optional list of policy IDs to override for this signer.
    public init(signerId: String, policyIds: [String]? = nil) {
        self.signerId = signerId
        self.policyIds = policyIds
    }
}
