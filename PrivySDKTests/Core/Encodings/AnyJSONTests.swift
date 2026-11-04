import XCTest
@testable import PrivySDK

internal final class AnyJSONTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Scalar decode/encode

    internal func testDecodesString() throws {
        let json = #""hello""#.data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .string(let s) = value else { return XCTFail("expected .string") }
        XCTAssertEqual(s, "hello")
    }

    internal func testDecodesInteger() throws {
        let json = "42".data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .integer(let n) = value else { return XCTFail("expected .integer") }
        XCTAssertEqual(n, 42)
    }

    internal func testDecodesFloat() throws {
        let json = "3.14".data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .number(let n) = value else { return XCTFail("expected .number") }
        XCTAssertEqual(n, 3.14, accuracy: 0.0001)
    }

    // MARK: - Integer precision

    /// 2^53 + 1: the first integer Double cannot represent exactly.
    internal func testDecodesLargeIntegerExactly() throws {
        let json = "9007199254740993".data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .integer(let n) = value else { return XCTFail("expected .integer, got \(value)") }
        XCTAssertEqual(n, 9_007_199_254_740_993)
    }

    internal func testDecodesUInt64MaxExactly() throws {
        let json = "\(UInt64.max)".data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .unsignedInteger(let n) = value else { return XCTFail("expected .unsignedInteger, got \(value)") }
        XCTAssertEqual(n, UInt64.max)
    }

    internal func testLargeIntegerRoundTripsExactly() throws {
        let original = "9007199254740993"
        let data = original.data(using: .utf8)!
        let decoded = try decoder.decode(AnyJSON.self, from: data)
        let reencoded = try encoder.encode(decoded)
        XCTAssertEqual(String(data: reencoded, encoding: .utf8), original)
    }

    internal func testUInt64MaxRoundTripsExactly() throws {
        let original = "\(UInt64.max)"
        let data = original.data(using: .utf8)!
        let decoded = try decoder.decode(AnyJSON.self, from: data)
        let reencoded = try encoder.encode(decoded)
        XCTAssertEqual(String(data: reencoded, encoding: .utf8), original)
    }

    internal func testDecodesBoolTrue() throws {
        let json = "true".data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .bool(let b) = value else { return XCTFail("expected .bool") }
        XCTAssertTrue(b)
    }

    internal func testDecodesBoolFalse() throws {
        let json = "false".data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .bool(let b) = value else { return XCTFail("expected .bool") }
        XCTAssertFalse(b)
    }

    internal func testDecodesNull() throws {
        let json = "null".data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .null = value else { return XCTFail("expected .null") }
    }

    // MARK: - Container decode/encode

    internal func testDecodesObject() throws {
        let json = #"{"key":"value"}"#.data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .object(let obj) = value else { return XCTFail("expected .object") }
        XCTAssertEqual(obj["key"], .string("value"))
    }

    internal func testDecodesArray() throws {
        let json = #"[1,2,3]"#.data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .array(let arr) = value else { return XCTFail("expected .array") }
        XCTAssertEqual(arr, [.integer(1), .integer(2), .integer(3)])
    }

    internal func testDecodesNestedObject() throws {
        let json = #"{"outer":{"inner":true,"list":[1,null]}}"#.data(using: .utf8)!
        let value = try decoder.decode(AnyJSON.self, from: json)
        guard case .object(let outer) = value,
              case .object(let inner) = outer["outer"],
              case .bool(let b) = inner["inner"],
              case .array(let list) = inner["list"],
              case .integer(let n) = list[0],
              case .null = list[1]
        else { return XCTFail("unexpected shape") }
        XCTAssertTrue(b)
        XCTAssertEqual(n, 1)
    }

    // MARK: - Round-trip

    internal func testRoundTripObject() throws {
        let original = #"{"name":"Dan","score":99,"active":true,"alias":null}"#
        let data = original.data(using: .utf8)!
        let decoded = try decoder.decode(AnyJSON.self, from: data)
        let reencoded = try encoder.encode(decoded)
        let redecoded = try decoder.decode(AnyJSON.self, from: reencoded)
        XCTAssertEqual(decoded, redecoded)
    }

    internal func testRoundTripNestedArray() throws {
        let original = #"[[1,2],["a","b"],[true,false],null]"#
        let data = original.data(using: .utf8)!
        let decoded = try decoder.decode(AnyJSON.self, from: data)
        let reencoded = try encoder.encode(decoded)
        let redecoded = try decoder.decode(AnyJSON.self, from: reencoded)
        XCTAssertEqual(decoded, redecoded)
    }

    // MARK: - EIP-712 typed data round-trip

    /// Tests that a realistic EIP-712 signTypedData_v4 payload decodes and re-encodes
    /// correctly — this is the behavior that was previously handled by SwiftyJSON.JSON.
    internal func testEIP712TypedDataRoundTrip() throws {
        let typedDataJSON = #"""
        {
          "domain": {
            "name": "Ether Mail",
            "version": "1",
            "chainId": 1,
            "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
          },
          "types": {
            "EIP712Domain": [
              {"name": "name", "type": "string"},
              {"name": "version", "type": "string"},
              {"name": "chainId", "type": "uint256"},
              {"name": "verifyingContract", "type": "address"}
            ],
            "Person": [
              {"name": "name", "type": "string"},
              {"name": "wallet", "type": "address"}
            ],
            "Mail": [
              {"name": "from", "type": "Person"},
              {"name": "to", "type": "Person"},
              {"name": "contents", "type": "string"}
            ]
          },
          "primaryType": "Mail",
          "message": {
            "from": {"name": "Cow", "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
            "to": {"name": "Bob", "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
            "contents": "Hello, Bob!"
          }
        }
        """#.data(using: .utf8)!

        // Decode using the same path as the RPC handler
        let params = try decoder.decode(
            WalletApiEthereumSignTypedDataV4RpcParams.EthereumTypedDataV4.self,
            from: typedDataJSON
        )

        // Verify key fields parsed correctly
        XCTAssertEqual(params.primaryType, "Mail")
        guard case .object(let domain) = params.domain else {
            return XCTFail("domain should be an object")
        }
        XCTAssertEqual(domain["name"], .string("Ether Mail"))
        XCTAssertEqual(domain["chainId"], .integer(1))

        guard case .object(let message) = params.message else {
            return XCTFail("message should be an object")
        }
        guard case .object(let from) = message["from"] else {
            return XCTFail("message.from should be an object")
        }
        XCTAssertEqual(from["name"], .string("Cow"))

        // Verify it re-encodes without error.
        // Note: the struct intentionally decodes from EIP-712 keys (e.g. "primaryType")
        // and encodes to snake_case backend keys (e.g. "primary_type"), so the output
        // is not re-decodable via the same init. We verify the encoded shape directly.
        let encoded = try encoder.encode(params)
        let obj = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        XCTAssertEqual(obj?["primary_type"] as? String, "Mail")
        XCTAssertNotNil(obj?["domain"])
        XCTAssertNotNil(obj?["message"])

        // Verify domain and message AnyJSON values re-encode stably
        let domainEncoded = try encoder.encode(params.domain)
        let domainRedecoded = try decoder.decode(AnyJSON.self, from: domainEncoded)
        XCTAssertEqual(params.domain, domainRedecoded)

        let messageEncoded = try encoder.encode(params.message)
        let messageRedecoded = try decoder.decode(AnyJSON.self, from: messageEncoded)
        XCTAssertEqual(params.message, messageRedecoded)
    }

    /// Verifies the encoding key rename: "primaryType" in JSON input → "primary_type" in JSON output.
    internal func testPrimaryTypeEncodingKey() throws {
        let input = #"{"domain":{},"types":{},"primaryType":"Foo","message":{}}"#.data(using: .utf8)!
        let decoded = try decoder.decode(
            WalletApiEthereumSignTypedDataV4RpcParams.EthereumTypedDataV4.self,
            from: input
        )
        let encoded = try encoder.encode(decoded)
        let obj = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        XCTAssertNotNil(obj?["primary_type"], "encoded key should be primary_type")
        XCTAssertNil(obj?["primaryType"], "camelCase key should not appear in output")
    }
}
