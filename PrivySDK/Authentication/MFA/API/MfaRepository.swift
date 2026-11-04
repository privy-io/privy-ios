import Foundation
internal import FactoryKit

internal protocol MfaRepository: Sendable {
    var totp: TotpMfaRepository { get }
    var sms: SmsMfaRepository { get }
    var passkey: PasskeyMfaRepository { get }
}

extension PrivyContainer {
    internal var mfaRepository: Factory<MfaRepository> {
        self { MfaRepositoryImpl() }.shared
    }
}

private final class MfaRepositoryImpl: MfaRepository {
    let totp: TotpMfaRepository = resolve(\PrivyContainer.totpMfaRepository)
    let sms: SmsMfaRepository = resolve(\PrivyContainer.smsMfaRepository)
    let passkey: PasskeyMfaRepository = resolve(\PrivyContainer.passkeyMfaRepository)
}
