import Foundation
import AuthenticationServices
internal import FactoryKit

extension PrivyContainer {
    internal var defaultASPresentationAnchorProvider: Factory<DefaultASPresentationAnchorProvider> {
        self { @MainActor in DefaultPresentationAnchorProviderImpl() }.shared
    }
}

internal protocol DefaultASPresentationAnchorProvider: Sendable {
    @MainActor
    func provide() -> ASPresentationAnchor
}

private final class DefaultPresentationAnchorProviderImpl: DefaultASPresentationAnchorProvider {
    @MainActor
    internal func provide() -> ASPresentationAnchor {
        #if canImport(UIKit)
            return UIApplication.shared.keyWindow ?? ASPresentationAnchor()
        #else
            return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #endif
    }
}
