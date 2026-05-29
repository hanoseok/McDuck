import Foundation
import Testing
@testable import McDuckCore

@Suite("ccusage daily JSON parser")
struct CcusageParserTests {
    @Test("parses modern daily JSON with model breakdown")
    func parsesModernDailyJSONWithBreakdown() throws {
        let json = """
        {
          "type": "daily",
          "data": [
            {
              "date": "2026-05-20",
              "models": ["claude-sonnet-4-5-20250929"],
              "inputTokens": 1200,
              "outputTokens": 3400,
              "cacheCreationTokens": 500,
              "cacheReadTokens": 700,
              "totalTokens": 5800,
              "costUSD": 2.75,
              "breakdown": {
                "claude-sonnet-4-5-20250929": {
                  "inputTokens": 1200,
                  "outputTokens": 3400,
                  "cacheCreationTokens": 500,
                  "cacheReadTokens": 700,
                  "totalTokens": 5800,
                  "costUSD": 2.75
                }
              }
            }
          ],
          "summary": {
            "totalInputTokens": 1200,
            "totalOutputTokens": 3400,
            "totalCacheCreationTokens": 500,
            "totalCacheReadTokens": 700,
            "totalTokens": 5800,
            "totalCost": 2.75
          }
        }
        """.data(using: .utf8)!

        let report = try CcusageParser().parseDailyJSON(json)

        #expect(report.days.count == 1)
        #expect(report.days[0].dateString == "2026-05-20")
        #expect(report.days[0].totalTokens == 5_800)
        #expect(report.days[0].costUSD == 2.75)
        #expect(report.days[0].models == ["claude-sonnet-4-5-20250929"])
        #expect(report.days[0].breakdown["claude-sonnet-4-5-20250929"]?.outputTokens == 3_400)
        #expect(report.summary.totalTokens == 5_800)
        #expect(report.summary.totalCostUSD == 2.75)
    }

    @Test("parses alternate daily and totals JSON")
    func parsesAlternateDailyTotalsJSON() throws {
        let json = """
        {
          "daily": [
            {
              "date": "2026-05-21",
              "modelsUsed": ["claude-opus-4-1-20250805"],
              "inputTokens": 200,
              "outputTokens": 300,
              "cacheCreationTokens": 40,
              "cacheReadTokens": 60,
              "totalTokens": 600,
              "totalCost": 1.25
            }
          ],
          "totals": {
            "inputTokens": 200,
            "outputTokens": 300,
            "cacheCreationTokens": 40,
            "cacheReadTokens": 60,
            "totalTokens": 600,
            "totalCost": 1.25
          }
        }
        """.data(using: .utf8)!

        let report = try CcusageParser().parseDailyJSON(json)

        #expect(report.days.map(\.dateString) == ["2026-05-21"])
        #expect(report.days[0].models == ["claude-opus-4-1-20250805"])
        #expect(report.days[0].costUSD == 1.25)
        #expect(report.summary.inputTokens == 200)
        #expect(report.summary.totalCostUSD == 1.25)
    }
}
