import Foundation
import McDuckCore
@testable import McDuckMCP

/// Error a fixture provider can be told to throw. A concrete, value-typed error
/// keeps `FakeUsageProvider` `Sendable` (a bare `Error?` would not be).
enum FixtureError: Error { case boom }

/// A provider that returns a fixed report (or throws) so the MCP handler can be
/// exercised without running ccusage.
struct FakeUsageProvider: UsageProviding {
    var stored: UsageReport
    var failure: FixtureError?

    func report() async throws -> UsageReport {
        if let failure { throw failure }
        return stored
    }
}

enum Fixtures {
    /// Two days, each with a per-model breakdown, plus a matching summary.
    static func report() -> UsageReport {
        let day1 = UsageDay(
            dateString: "2026-06-01",
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationTokens: 10,
            cacheReadTokens: 5,
            totalTokens: 165,
            costUSD: 1.25,
            models: ["opus", "sonnet"],
            breakdown: [
                "opus": ModelUsage(inputTokens: 80, outputTokens: 40, cacheCreationTokens: 8, cacheReadTokens: 4, totalTokens: 132, costUSD: 1.0),
                "sonnet": ModelUsage(inputTokens: 20, outputTokens: 10, cacheCreationTokens: 2, cacheReadTokens: 1, totalTokens: 33, costUSD: 0.25)
            ]
        )
        let day2 = UsageDay(
            dateString: "2026-06-02",
            inputTokens: 200,
            outputTokens: 100,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalTokens: 300,
            costUSD: 2.0,
            models: ["opus"],
            breakdown: [
                "opus": ModelUsage(inputTokens: 200, outputTokens: 100, cacheCreationTokens: 0, cacheReadTokens: 0, totalTokens: 300, costUSD: 2.0)
            ]
        )
        let summary = UsageSummary(
            inputTokens: 300,
            outputTokens: 150,
            cacheCreationTokens: 10,
            cacheReadTokens: 5,
            totalTokens: 465,
            totalCostUSD: 3.25
        )
        return UsageReport(days: [day1, day2], summary: summary)
    }

    static func handler(failure: FixtureError? = nil) -> MCPRequestHandler {
        MCPRequestHandler(provider: FakeUsageProvider(stored: report(), failure: failure))
    }

    static func request(method: String, id: Int? = 1, params: JSONValue? = nil) -> JSONRPCRequest {
        JSONRPCRequest(id: id.map(JSONRPCID.int), method: method, params: params)
    }

    static func callRequest(tool: String, arguments: JSONValue? = nil, id: Int = 1) -> JSONRPCRequest {
        var params: [String: JSONValue] = ["name": .string(tool)]
        if let arguments { params["arguments"] = arguments }
        return request(method: "tools/call", id: id, params: .object(params))
    }
}
