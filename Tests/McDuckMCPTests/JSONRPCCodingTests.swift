import Foundation
import Testing
@testable import McDuckMCP

@Suite("json-rpc coding")
struct JSONRPCCodingTests {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    @Test("decodes a request with object params and an integer id")
    func decodeRequest() throws {
        let json = #"{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"usage_summary"}}"#
        let request = try decoder.decode(JSONRPCRequest.self, from: Data(json.utf8))

        #expect(request.id == .int(7))
        #expect(request.method == "tools/call")
        #expect(request.params?["name"]?.stringValue == "usage_summary")
    }

    @Test("decodes a notification (no id) with id nil")
    func decodeNotification() throws {
        let json = #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#
        let request = try decoder.decode(JSONRPCRequest.self, from: Data(json.utf8))
        #expect(request.id == nil)
    }

    @Test("decodes a string request id")
    func decodeStringID() throws {
        let json = #"{"jsonrpc":"2.0","id":"req-1","method":"ping"}"#
        let request = try decoder.decode(JSONRPCRequest.self, from: Data(json.utf8))
        #expect(request.id == .string("req-1"))
    }

    @Test("a success response encodes jsonrpc, id, and result and decodes back")
    func encodeSuccess() throws {
        let response = JSONRPCResponse.success(id: .int(1), result: .object(["ok": .bool(true)]))
        let data = try encoder.encode(response)

        // No embedded newline: the stdio transport is newline-delimited.
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"jsonrpc\":\"2.0\"") || text.contains("\"jsonrpc\" :"))
        #expect(!text.contains("\n"))

        let decoded = try decoder.decode(ProbeResponse.self, from: data)
        #expect(decoded.id == 1)
        #expect(decoded.result?["ok"] == true)
        #expect(decoded.error == nil)
    }

    @Test("a failure response encodes a nested error with code and message")
    func encodeFailure() throws {
        let response = JSONRPCResponse.failure(
            id: .int(2),
            error: JSONRPCError(code: JSONRPCError.methodNotFound, message: "nope")
        )
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(ProbeResponse.self, from: data)

        #expect(decoded.error?.code == JSONRPCError.methodNotFound)
        #expect(decoded.error?.message == "nope")
        #expect(decoded.result == nil)
    }
}

/// A loosely-typed decoder for the encoded response, independent of the
/// production encoder so the test checks the actual wire shape.
private struct ProbeResponse: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: [String: Bool]?
    let error: ProbeError?

    struct ProbeError: Decodable {
        let code: Int
        let message: String
    }
}
