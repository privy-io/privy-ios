internal import FactoryKit

internal final class PrivyContainer: SharedContainer {
    internal static let shared = PrivyContainer()
    internal let manager = ContainerManager()

    internal var config: Factory<PrivyConfig> {
        self { fatalError("PrivySdk.initialize was not called") }.singleton
    }

    /// The MFA configuration.
    ///
    /// This can be updated at runtime via `privy.mfa.setConfig(_:)`.
    internal var mfaConfig: Factory<PrivyMFAConfig> {
        self { self.config().mfaConfig }
    }

    internal func initialize(config: PrivyConfig) {
        self.config.register { config }

        PrivyContainer.shared.logger().setInfo(appInfo: config)
    }
}
