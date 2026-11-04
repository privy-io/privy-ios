import XCTest
@testable import PrivySDK

internal final class WalletApiRpcTests: XCTestCase {
    private let decoder = JSONDecoder()

    private func encodedString<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(data: try encoder.encode(value), encoding: .utf8)!
    }

    private func decodeResponse(_ json: String) throws -> WalletApiRpcResponse {
        try decoder.decode(WalletApiRpcResponse.self, from: Data(json.utf8))
    }

    // MARK: - Request encoding

    internal func testEncodesPersonalSignWithUtf8Encoding() throws {
        let request = WalletApiRpcRequest.ethereumPersonalSign(
            WalletApiEthereumPersonalSignRpcParams(message: "hello", encoding: .utf8)
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"method":"personal_sign","params":{"encoding":"utf-8","message":"hello"}}"#
        )
    }

    internal func testEncodesPersonalSignWithHexEncoding() throws {
        let request = WalletApiRpcRequest.ethereumPersonalSign(
            WalletApiEthereumPersonalSignRpcParams(message: "0xdeadbeef", encoding: .hex)
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"method":"personal_sign","params":{"encoding":"hex","message":"0xdeadbeef"}}"#
        )
    }

    internal func testEncodesSecp256k1Sign() throws {
        let request = WalletApiRpcRequest.ethereumSecp256k1Sign(
            WalletApiEthereumSecp256k1SignRpcParams(hash: "0xabc123")
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"method":"secp256k1_sign","params":{"hash":"0xabc123"}}"#
        )
    }

    internal func testEncodesEthereumSignTransactionWithoutCaip2() throws {
        let transaction = WalletApiUnsignedEthereumTransaction(
            from: nil, to: "0xabc", nonce: nil, gasLimit: "0x5208", gasPrice: nil, data: nil,
            value: nil, chainId: 1, type: nil, maxFeePerGas: nil, maxPriorityFeePerGas: nil
        )
        let request = WalletApiRpcRequest.ethereumSignTransaction(
            WalletApiEthereumSignTransactionRpcParams(transaction: transaction)
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"method":"eth_signTransaction","params":{"transaction":{"chain_id":1,"gas_limit":"0x5208","to":"0xabc"}}}"#
        )
    }

    internal func testEncodesEthereumSendTransactionWithCaip2() throws {
        let transaction = WalletApiUnsignedEthereumTransaction(
            from: nil, to: "0xabc", nonce: nil, gasLimit: nil, gasPrice: nil, data: nil,
            value: "0x1", chainId: 1, type: 2, maxFeePerGas: "0x10", maxPriorityFeePerGas: "0x2"
        )
        let request = WalletApiRpcRequest.ethereumSendTransaction(
            WalletApiEthereumSendTransactionRpcParams(transaction: transaction),
            WalletApiCAIP2(eip155: 1)
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"caip2":"eip155:1","method":"eth_sendTransaction","params":{"transaction":{"chain_id":1,"max_fee_per_gas":"0x10","max_priority_fee_per_gas":"0x2","to":"0xabc","type":2,"value":"0x1"}}}"#
        )
    }

    internal func testEncodesSolanaSignMessageWithBase64Encoding() throws {
        let request = WalletApiRpcRequest.solanaSignMessage(
            WalletApiSolanaSignMessageRpcParams(message: "aGk=")
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"method":"signMessage","params":{"encoding":"base64","message":"aGk="}}"#
        )
    }

    internal func testEncodesSolanaSignTransactionWithBase64Encoding() throws {
        let request = WalletApiRpcRequest.solanaSignTransaction(
            WalletApiSolanaSignTransactionRpcParams(transaction: "dHg=")
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"method":"signTransaction","params":{"encoding":"base64","transaction":"dHg="}}"#
        )
    }

    internal func testEncodesSolanaSignAndSendTransactionWithCaip2() throws {
        let caip2 = try XCTUnwrap(WalletApiCAIP2(string: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"))
        let request = WalletApiRpcRequest.solanaSignAndSendTransaction(
            WalletApiSolanaSignAndSendTransactionRpcParams(transaction: "dHg="),
            caip2
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"caip2":"solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp","method":"signAndSendTransaction","params":{"encoding":"base64","transaction":"dHg="}}"#
        )
    }

    internal func testEncodesSignTypedDataV4UsingSnakeCaseKeys() throws {
        let typedDataJson = """
        {
          "domain": {"name": "Test"},
          "types": {"Mail": [{"name": "contents", "type": "string"}]},
          "message": {"contents": "hi"},
          "primaryType": "Mail"
        }
        """
        let typedData = try decoder.decode(
            WalletApiEthereumSignTypedDataV4RpcParams.EthereumTypedDataV4.self,
            from: Data(typedDataJson.utf8)
        )
        let request = WalletApiRpcRequest.ethereumSignTypedDataV4(
            WalletApiEthereumSignTypedDataV4RpcParams(typedData: typedData)
        )
        XCTAssertEqual(
            try encodedString(request),
            #"{"method":"eth_signTypedData_v4","params":{"typed_data":{"domain":{"name":"Test"},"message":{"contents":"hi"},"primary_type":"Mail","types":{"Mail":[{"name":"contents","type":"string"}]}}}}"#
        )
    }

    // MARK: - Typed data decoding

    internal func testTypedDataDecodingReadsCamelCasePrimaryType() throws {
        let json = #"{"domain":{},"types":{},"message":{},"primaryType":"Mail"}"#
        let typedData = try decoder.decode(
            WalletApiEthereumSignTypedDataV4RpcParams.EthereumTypedDataV4.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(typedData.primaryType, "Mail")
    }

    internal func testTypedDataDecodingFailsWhenPrimaryTypeIsMissing() {
        let json = #"{"domain":{},"types":{},"message":{}}"#
        XCTAssertThrowsError(
            try decoder.decode(
                WalletApiEthereumSignTypedDataV4RpcParams.EthereumTypedDataV4.self,
                from: Data(json.utf8)
            )
        )
    }

    // MARK: - Response decoding

    internal func testDecodesPersonalSignResponse() throws {
        let response = try decodeResponse(#"{"method":"personal_sign","data":{"signature":"0xsig"}}"#)
        guard case .ethereumPersonalSign(let result) = response else { return XCTFail("expected personal_sign") }
        XCTAssertEqual(result.signature, "0xsig")
    }

    internal func testDecodesSecp256k1SignResponse() throws {
        let response = try decodeResponse(#"{"method":"secp256k1_sign","data":{"signature":"0xsig"}}"#)
        guard case .ethereumSecp256k1Sign(let result) = response else { return XCTFail("expected secp256k1_sign") }
        XCTAssertEqual(result.signature, "0xsig")
    }

    internal func testDecodesEthereumSignTransactionResponse() throws {
        let response = try decodeResponse(
            #"{"method":"eth_signTransaction","data":{"signed_transaction":"0xsigned"}}"#
        )
        guard case .ethereumSignTransaction(let result) = response else {
            return XCTFail("expected eth_signTransaction")
        }
        XCTAssertEqual(result.signed_transaction, "0xsigned")
    }

    internal func testDecodesEthereumSendTransactionResponse() throws {
        let response = try decodeResponse(
            #"{"method":"eth_sendTransaction","data":{"transaction_id":"tx1","hash":"0xhash","caip2":"eip155:137"}}"#
        )
        guard case .ethereumSendTransaction(let result) = response else {
            return XCTFail("expected eth_sendTransaction")
        }
        XCTAssertEqual(result.transaction_id, "tx1")
        XCTAssertEqual(result.hash, "0xhash")
        XCTAssertEqual(try encodedString(result.caip2), #""eip155:137""#)
    }

    internal func testDecodesSignTypedDataV4Response() throws {
        let response = try decodeResponse(#"{"method":"eth_signTypedData_v4","data":{"signature":"0xsig"}}"#)
        guard case .ethereumSignTypedDataV4(let result) = response else {
            return XCTFail("expected eth_signTypedData_v4")
        }
        XCTAssertEqual(result.signature, "0xsig")
    }

    internal func testDecodesSolanaSignMessageResponse() throws {
        let response = try decodeResponse(#"{"method":"signMessage","data":{"signature":"c2ln"}}"#)
        guard case .solanaSignMessage(let result) = response else { return XCTFail("expected signMessage") }
        XCTAssertEqual(result.signature, "c2ln")
    }

    internal func testDecodesSolanaSignTransactionResponse() throws {
        let response = try decodeResponse(
            #"{"method":"signTransaction","data":{"signed_transaction":"c2lnbmVk","encoding":"base64"}}"#
        )
        guard case .solanaSignTransaction(let result) = response else {
            return XCTFail("expected signTransaction")
        }
        XCTAssertEqual(result.signed_transaction, "c2lnbmVk")
        XCTAssertEqual(result.encoding, .base64)
    }

    internal func testDecodesSolanaSignAndSendTransactionResponse() throws {
        let response = try decodeResponse(#"{"method":"signAndSendTransaction","data":{"hash":"solhash"}}"#)
        guard case .solanaSignAndSendTransaction(let result) = response else {
            return XCTFail("expected signAndSendTransaction")
        }
        XCTAssertEqual(result.hash, "solhash")
    }

    internal func testDecodingUnknownMethodThrowsDataCorrupted() {
        XCTAssertThrowsError(try decodeResponse(#"{"method":"eth_unknown","data":{}}"#)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                return XCTFail("expected dataCorrupted, got \(error)")
            }
            XCTAssertTrue(context.debugDescription.contains("eth_unknown"))
        }
    }

    internal func testDecodingResponseWithMismatchedDataThrows() {
        // personal_sign expects `signature`, not `hash`
        XCTAssertThrowsError(try decodeResponse(#"{"method":"personal_sign","data":{"hash":"0x"}}"#))
    }

    // MARK: - CAIP-2

    internal func testCaip2AcceptsValidIdentifiers() {
        XCTAssertNotNil(WalletApiCAIP2(string: "eip155:1"))
        XCTAssertNotNil(WalletApiCAIP2(string: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"))
        XCTAssertNotNil(WalletApiCAIP2(string: "cosmos:cosmoshub-3"))
    }

    internal func testCaip2RejectsInvalidIdentifiers() {
        XCTAssertNil(WalletApiCAIP2(string: ""))
        XCTAssertNil(WalletApiCAIP2(string: "eip155"))
        XCTAssertNil(WalletApiCAIP2(string: "eip155:"))
        XCTAssertNil(WalletApiCAIP2(string: ":1"))
        XCTAssertNil(WalletApiCAIP2(string: "ab:1")) // namespace too short
        XCTAssertNil(WalletApiCAIP2(string: "abcdefghi:1")) // namespace too long
        XCTAssertNil(WalletApiCAIP2(string: "EIP155:1")) // namespace must be lowercase
        XCTAssertNil(WalletApiCAIP2(string: "eip155:" + String(repeating: "a", count: 33)))
        XCTAssertNil(WalletApiCAIP2(string: "eip155:1 "))
    }

    internal func testCaip2Eip155InitBuildsChainIdentifier() throws {
        XCTAssertEqual(try encodedString(WalletApiCAIP2(eip155: 137)), #""eip155:137""#)
    }

    internal func testCaip2RoundTripsThroughJson() throws {
        let decoded = try decoder.decode(WalletApiCAIP2.self, from: Data(#""eip155:8453""#.utf8))
        XCTAssertEqual(try encodedString(decoded), #""eip155:8453""#)
    }

    internal func testCaip2DecodingRejectsInvalidIdentifier() {
        XCTAssertThrowsError(try decoder.decode(WalletApiCAIP2.self, from: Data(#""not-a-chain""#.utf8))) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("expected dataCorrupted, got \(error)")
            }
        }
    }

    // MARK: - Unsigned transaction

    internal func testUnsignedTransactionOmitsNilFields() throws {
        let transaction = WalletApiUnsignedEthereumTransaction(
            from: nil, to: nil, nonce: nil, gasLimit: nil, gasPrice: nil, data: nil,
            value: nil, chainId: nil, type: nil, maxFeePerGas: nil, maxPriorityFeePerGas: nil
        )
        XCTAssertEqual(try encodedString(transaction), "{}")
    }

    internal func testUnsignedTransactionEncodesAllFieldsWithSnakeCaseKeys() throws {
        let transaction = WalletApiUnsignedEthereumTransaction(
            from: "0xfrom", to: "0xto", nonce: "0x1", gasLimit: "0x5208", gasPrice: "0x3b9aca00",
            data: "0xdata", value: "0x2", chainId: 10, type: 0, maxFeePerGas: "0x10",
            maxPriorityFeePerGas: "0x2"
        )
        XCTAssertEqual(
            try encodedString(transaction),
            #"{"chain_id":10,"data":"0xdata","from":"0xfrom","gas_limit":"0x5208","gas_price":"0x3b9aca00","max_fee_per_gas":"0x10","max_priority_fee_per_gas":"0x2","nonce":"0x1","to":"0xto","type":0,"value":"0x2"}"#
        )
    }
}
