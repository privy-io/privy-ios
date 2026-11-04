import XCTest
@testable import PrivySDK

internal final class Base64DataTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    internal func testEncodesAsAPaddedBase64String() throws {
        let json = try encoder.encode(Base64Data(Data([0xFB, 0xFF, 0x00, 0x01])))

        XCTAssertEqual(try decoder.decode(String.self, from: json), "+/8AAQ==")
    }

    internal func testDecodesAPaddedBase64String() throws {
        let value = try decoder.decode(Base64Data.self, from: Data(#""+/8AAQ==""#.utf8))

        XCTAssertEqual(value.data, Data([0xFB, 0xFF, 0x00, 0x01]))
    }

    internal func testRoundTripsArbitraryBytes() throws {
        let data = Data((0 ... 255).map { UInt8($0) })

        let value = try decoder.decode(Base64Data.self, from: encoder.encode(Base64Data(data)))

        XCTAssertEqual(value.data, data)
    }

    internal func testRoundTripsEmptyData() throws {
        let value = try decoder.decode(Base64Data.self, from: encoder.encode(Base64Data(Data())))

        XCTAssertEqual(value.data, Data())
    }

    internal func testInvalidBase64FailsWithoutRevealingTheString() {
        // "-" and "_" are the URL-safe alphabet, which isn't accepted
        let invalidStrings = ["not base64!", "-_8AAQ==", "+/8AAQ"]

        for invalidString in invalidStrings {
            XCTAssertThrowsError(try decoder.decode(Base64Data.self, from: JSONEncoder().encode(invalidString))) { error in
                guard case DecodingError.dataCorrupted(let context) = error else {
                    return XCTFail("Expected dataCorrupted, got \(error)")
                }
                XCTAssertFalse(context.debugDescription.contains(invalidString))
            }
        }
    }

    internal func testNonStringFailsToDecode() {
        XCTAssertThrowsError(try decoder.decode(Base64Data.self, from: Data("42".utf8)))
    }
}
