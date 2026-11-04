import Foundation

/// The class used for initializing the Privy SDK
public actor PrivySdk {
    nonisolated(unsafe) private static var alreadyInitialized: Bool = false

    /**
     * Iniitalizes the PrivySDK.
     *
     * - Returns: A Privy instance, which should be used through the lifetime of the application.
     *
     * - Throws: A fatal error if `intialize` is called more than once
     */
    public static func initialize(config: PrivyConfig) -> Privy {
        guard !alreadyInitialized else {
            fatalError("Found multiple instances of Privy, ensure there is only one call made to PrivySdk.initialize in your application")
        }

        alreadyInitialized = true

        PrivyContainer.shared.initialize(config: config)
        return PrivyImpl()
    }
}
