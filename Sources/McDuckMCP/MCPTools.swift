import Foundation
import McDuckCore

/// The tools McDuck exposes over MCP, plus the aggregation that backs them.
/// Kept free of I/O so it can be unit-tested with a fixed `UsageReport`.
public enum MCPTools {
    public static let usageSummary = "usage_summary"
    public static let dailyUsage = "daily_usage"
    public static let modelBreakdown = "model_breakdown"

    /// Tool descriptors for `tools/list`. `start`/`end` are inclusive
    /// `yyyy-MM-dd` bounds; omitting both means the full available history.
    public static func definitions() -> JSONValue {
        let dateRangeSchema = JSONValue.object([
            "type": .string("object"),
            "properties": .object([
                "start": .object([
                    "type": .string("string"),
                    "description": .string("Inclusive start date, yyyy-MM-dd. Omit for the earliest available day.")
                ]),
                "end": .object([
                    "type": .string("string"),
                    "description": .string("Inclusive end date, yyyy-MM-dd. Omit for the latest available day.")
                ])
            ])
        ])

        return .array([
            tool(
                name: usageSummary,
                description: "Total Claude/LLM token usage and cost (USD) over an optional date range, from ccusage.",
                inputSchema: dateRangeSchema
            ),
            tool(
                name: dailyUsage,
                description: "Per-day token totals and cost (USD) over an optional date range.",
                inputSchema: dateRangeSchema
            ),
            tool(
                name: modelBreakdown,
                description: "Per-model token totals and cost (USD) aggregated over an optional date range.",
                inputSchema: dateRangeSchema
            )
        ])
    }

    /// Runs a tool against an already-fetched report. Returns the `tools/call`
    /// result object (`{ content: [...], structuredContent: {...} }`) or throws
    /// a JSON-RPC error for an unknown tool.
    public static func call(name: String, arguments: JSONValue?, report: UsageReport) throws -> JSONValue {
        let days = filteredDays(report.days, arguments: arguments)
        switch name {
        case usageSummary:
            return summaryResult(days: days)
        case dailyUsage:
            return dailyResult(days: days)
        case modelBreakdown:
            return modelResult(days: days)
        default:
            throw JSONRPCError(code: JSONRPCError.invalidParams, message: "Unknown tool: \(name)")
        }
    }

    // MARK: - Filtering

    /// Filters days by the optional inclusive `start`/`end` bounds. `yyyy-MM-dd`
    /// strings sort lexicographically, so plain string comparison is correct.
    static func filteredDays(_ days: [UsageDay], arguments: JSONValue?) -> [UsageDay] {
        let start = arguments?["start"]?.stringValue
        let end = arguments?["end"]?.stringValue
        return days.filter { day in
            if let start, day.dateString < start { return false }
            if let end, day.dateString > end { return false }
            return true
        }
        .sorted { $0.dateString < $1.dateString }
    }

    // MARK: - Result builders

    private static func summaryResult(days: [UsageDay]) -> JSONValue {
        let input = days.reduce(0) { $0 + $1.inputTokens }
        let output = days.reduce(0) { $0 + $1.outputTokens }
        let cacheCreation = days.reduce(0) { $0 + $1.cacheCreationTokens }
        let cacheRead = days.reduce(0) { $0 + $1.cacheReadTokens }
        let total = days.reduce(0) { $0 + $1.totalTokens }
        let cost = days.reduce(0.0) { $0 + $1.costUSD }

        let structured = JSONValue.object([
            "inputTokens": .int(input),
            "outputTokens": .int(output),
            "cacheCreationTokens": .int(cacheCreation),
            "cacheReadTokens": .int(cacheRead),
            "totalTokens": .int(total),
            "totalCostUSD": .double(cost),
            "activeDays": .int(days.count)
        ])

        let text = "Total: \(total) tokens, \(currency(cost)) across \(days.count) day(s)."
        return result(text: text, structured: structured)
    }

    private static func dailyResult(days: [UsageDay]) -> JSONValue {
        let rows = days.map { day in
            JSONValue.object([
                "date": .string(day.dateString),
                "totalTokens": .int(day.totalTokens),
                "inputTokens": .int(day.inputTokens),
                "outputTokens": .int(day.outputTokens),
                "cacheCreationTokens": .int(day.cacheCreationTokens),
                "cacheReadTokens": .int(day.cacheReadTokens),
                "costUSD": .double(day.costUSD)
            ])
        }
        let structured = JSONValue.object(["days": .array(rows)])
        let text = days.isEmpty
            ? "No usage in the requested range."
            : days.map { "\($0.dateString): \($0.totalTokens) tokens, \(currency($0.costUSD))" }
                .joined(separator: "\n")
        return result(text: text, structured: structured)
    }

    private static func modelResult(days: [UsageDay]) -> JSONValue {
        var totals: [String: (tokens: Int, cost: Double)] = [:]
        for day in days {
            for (model, usage) in day.breakdown {
                let current = totals[model] ?? (0, 0)
                totals[model] = (current.tokens + usage.totalTokens, current.cost + usage.costUSD)
            }
        }

        let sorted = totals.sorted { $0.value.tokens > $1.value.tokens }
        let rows = sorted.map { entry in
            JSONValue.object([
                "model": .string(entry.key),
                "totalTokens": .int(entry.value.tokens),
                "costUSD": .double(entry.value.cost)
            ])
        }
        let structured = JSONValue.object(["models": .array(rows)])
        let text = sorted.isEmpty
            ? "No per-model breakdown in the requested range."
            : sorted.map { "\($0.key): \($0.value.tokens) tokens, \(currency($0.value.cost))" }
                .joined(separator: "\n")
        return result(text: text, structured: structured)
    }

    // MARK: - Helpers

    private static func tool(name: String, description: String, inputSchema: JSONValue) -> JSONValue {
        .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": inputSchema
        ])
    }

    private static func result(text: String, structured: JSONValue) -> JSONValue {
        .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(text)
                ])
            ]),
            "structuredContent": structured
        ])
    }

    private static func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}
