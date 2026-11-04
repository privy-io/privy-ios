import XCTest
@testable import PrivySDK

internal final class WalletImportSecretTests: XCTestCase {
    private static let privateKey = Data((1 ... 32).map { UInt8($0) })
    private static let mnemonic = Array(repeating: "abandon", count: 11).joined(separator: " ") + " about"

    internal func testDescriptionsNeverContainTheSecret() {
        let secrets: [(secret: WalletImportSecret, values: [String])] = [
            (.privateKey(Self.privateKey), [Self.privateKey.base64EncodedString(), Self.privateKey.map { String($0) }.joined(separator: ", ")]),
            (.mnemonic(Self.mnemonic, index: 7), ["abandon", "about", "7"]),
        ]

        for (secret, values) in secrets {
            var dumped = ""
            dump(secret, to: &dumped)

            for output in ["\(secret)", String(describing: secret), String(reflecting: secret), dumped] {
                for value in values {
                    XCTAssertFalse(output.contains(value), "\(output) contains the secret")
                }
                XCTAssertTrue(output.contains("<redacted>"), "\(output) is not redacted")
            }
        }
    }

    internal func testDescriptionNamesTheKindOfSecret() {
        XCTAssertEqual(WalletImportSecret.privateKey(Self.privateKey).description, "WalletImportSecret.privateKey(<redacted>)")
        XCTAssertEqual(WalletImportSecret.mnemonic(Self.mnemonic, index: 7).description, "WalletImportSecret.mnemonic(<redacted>)")
    }
}
