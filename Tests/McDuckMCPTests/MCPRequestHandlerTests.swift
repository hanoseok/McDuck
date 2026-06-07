import Foundation
import Testing
import McDuckCore
@testable import McDuckMCP

@Suite("mcp request handler")
struct MCPRequestHandlerTests {
    // MARK: - Handshake

    @Test("initialize returns protocol version, tools capability, and server info")
    func initialize() async throws {
        let response = try #require(await Fixtures.handler().handle(Fixtures.request(method: "initialize")))
        let result = try #require(response.result)

        #expect(result["protocolVersion"]?.stringValue == "2025-06-18")
        #expect(result["capabilities"]?["tools"] != nil)
        #expect(result["serverInfo"]?["name"]?.stringValue == "mcduck")
        #expect(response.error == nil)
    }

    @Test("tools/list advertises the three usage tools with input schemas")
    func toolsList() async throws {
        let response = try #require(await Fixtures.handler().handle(Fixtures.request(method: "tools/list")))
        let tools = try #require(response.result?["tools"]?.arrayValue)

        let names = tools.compactMap { $0["name"]?.stringValue }
        #expect(Set(names) == Set([MCPTools.usageSummary, MCPTools.dailyUsage, MCPTools.modelBreakdown]))
        // Every tool exposes an object input schema.
        for tool in tools {
            #expect(tool["inputSchema"]?["type"]?.stringValue == "object")
        }
    }

    // MARK: - Routing

    @Test("an unknown method returns method-not-found")
    func unknownMethod() async throws {
        let response = try #require(await Fixtures.handler().handle(Fixtures.request(method: "does/notExist")))
        #expect(response.error?.code == JSONRPCError.methodNotFound)
    }

    @Test("a notification (no id) is not answered")
    func notificationIgnored() async {
        let request = JSONRPCRequest(id: nil, method: "notifications/initialized", params: nil)
        let response = await Fixtures.handler().handle(request)
        #expect(response == nil)
    }

    @Test("tools/call without a name is an invalid-params error")
    func callMissingName() async throws {
        let request = Fixtures.request(method: "tools/call", params: .object([:]))
        let response = try #require(await Fixtures.handler().handle(request))
        #expect(response.error?.code == JSONRPCError.invalidParams)
    }

    @Test("calling an unknown tool is an invalid-params error")
    func callUnknownTool() async throws {
        let response = try #require(await Fixtures.handler().handle(Fixtures.callRequest(tool: "nope")))
        #expect(response.error?.code == JSONRPCError.invalidParams)
    }

    // MARK: - Tool results

    @Test("usage_summary totals tokens and cost across all days")
    func usageSummaryAll() async throws {
        let response = try #require(await Fixtures.handler().handle(Fixtures.callRequest(tool: MCPTools.usageSummary)))
        let structured = try #require(response.result?["structuredContent"])

        #expect(structured["totalTokens"]?.intValue == 465)
        #expect(structured["totalCostUSD"]?.doubleValue == 3.25)
        #expect(structured["activeDays"]?.intValue == 2)
    }

    @Test("usage_summary respects an inclusive date range")
    func usageSummaryRanged() async throws {
        let args = JSONValue.object(["start": .string("2026-06-02"), "end": .string("2026-06-02")])
        let response = try #require(await Fixtures.handler().handle(Fixtures.callRequest(tool: MCPTools.usageSummary, arguments: args)))
        let structured = try #require(response.result?["structuredContent"])

        #expect(structured["totalTokens"]?.intValue == 300)
        #expect(structured["activeDays"]?.intValue == 1)
    }

    @Test("daily_usage lists each day in range, sorted by date")
    func dailyUsage() async throws {
        let response = try #require(await Fixtures.handler().handle(Fixtures.callRequest(tool: MCPTools.dailyUsage)))
        let rows = try #require(response.result?["structuredContent"]?["days"]?.arrayValue)

        #expect(rows.count == 2)
        #expect(rows.first?["date"]?.stringValue == "2026-06-01")
        #expect(rows.last?["totalTokens"]?.intValue == 300)
    }

    @Test("model_breakdown aggregates per model across days, ranked by tokens")
    func modelBreakdown() async throws {
        let response = try #require(await Fixtures.handler().handle(Fixtures.callRequest(tool: MCPTools.modelBreakdown)))
        let models = try #require(response.result?["structuredContent"]?["models"]?.arrayValue)

        // opus appears on both days (132 + 300 = 432), sonnet only on day 1 (33).
        #expect(models.first?["model"]?.stringValue == "opus")
        #expect(models.first?["totalTokens"]?.intValue == 432)
        #expect(models.count == 2)
    }

    @Test("a provider failure becomes a tool error result, not a transport error")
    func providerFailure() async throws {
        let handler = Fixtures.handler(failure: FixtureError.boom)
        let response = try #require(await handler.handle(Fixtures.callRequest(tool: MCPTools.usageSummary)))

        // Transport-level success, but the result is flagged as an error.
        #expect(response.error == nil)
        #expect(response.result?["isError"]?.boolValue == true)
    }
}
