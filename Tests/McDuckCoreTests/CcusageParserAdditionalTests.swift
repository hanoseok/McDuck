import Foundation
import Testing
@testable import McDuckCore

/// Edge-case coverage for `CcusageParser` beyond the happy-path cases in
/// `CcusageParserTests`: empty/invalid payloads, sorting, summary fallbacks,
/// per-model derivation, and `blocks` duration accounting.
@Suite("ccusage parser edge cases")
struct CcusageParserAdditionalTests {
    private func parse(_ json: String) throws -> UsageReport {
        try CcusageParser().parseDailyJSON(Data(json.utf8))
    }

    // MARK: - Daily payload guards

    @Test("empty data array throws missingDailyData")
    func emptyDataThrowsMissingDailyData() {
        let json = #"{"type":"daily","data":[]}"#
        #expect(throws: CcusageParseError.missingDailyData) {
            try parse(json)
        }
    }

    @Test("payload whose only entries lack a date throws missingDailyData")
    func allDatelessThrowsMissingDailyData() {
        let json = #"{"daily":[{"inputTokens":5,"outputTokens":5,"totalTokens":10}]}"#
        #expect(throws: CcusageParseError.missingDailyData) {
            try parse(json)
        }
    }

    @Test("empty output is surfaced as a readable unreadable error")
    func emptyOutputIsReadableError() {
        #expect(throws: CcusageParseError.unreadable("Output was empty.")) {
            try parse("")
        }
    }

    @Test("malformed JSON throws the unreadable case with the original snippet")
    func malformedJSONReportsSnippet() {
        do {
            _ = try parse("totally not json")
            Issue.record("Expected parsing to throw")
        } catch let error as CcusageParseError {
            guard case .unreadable(let detail) = error else {
                Issue.record("Expected .unreadable, got \(error)")
                return
            }
            #expect(detail.contains("totally not json"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Ordering & field fallbacks

    @Test("days are returned sorted ascending by date regardless of input order")
    func daysSortedAscending() throws {
        let json = """
        {
          "daily": [
            { "date": "2026-05-03", "totalTokens": 30, "totalCost": 0.3 },
            { "date": "2026-05-01", "totalTokens": 10, "totalCost": 0.1 },
            { "date": "2026-05-02", "totalTokens": 20, "totalCost": 0.2 }
          ]
        }
        """

        let report = try parse(json)

        #expect(report.days.map(\.dateString) == ["2026-05-01", "2026-05-02", "2026-05-03"])
    }

    @Test("an unparseable date string skips just that entry")
    func invalidDateStringSkipsEntry() throws {
        let json = """
        {
          "daily": [
            { "date": "nope", "totalTokens": 5 },
            { "date": "2026-05-01", "totalTokens": 7 }
          ]
        }
        """

        let report = try parse(json)

        #expect(report.days.map(\.dateString) == ["2026-05-01"])
        #expect(report.days[0].totalTokens == 7)
    }

    @Test("models fall back to the sorted breakdown keys when none are listed")
    func modelsFallBackToBreakdownKeys() throws {
        let json = """
        {
          "daily": [
            {
              "date": "2026-05-01",
              "totalTokens": 3,
              "breakdown": {
                "zeta": { "totalTokens": 1 },
                "alpha": { "totalTokens": 2 }
              }
            }
          ]
        }
        """

        let report = try parse(json)

        #expect(report.days[0].models == ["alpha", "zeta"])
    }

    // MARK: - Per-model breakdown derivation

    @Test("breakdown total is derived from components when omitted")
    func breakdownTotalDerivedWhenMissing() throws {
        let json = """
        {
          "daily": [
            {
              "date": "2026-05-01",
              "breakdown": {
                "m": {
                  "inputTokens": 100,
                  "outputTokens": 50,
                  "cacheCreationTokens": 10,
                  "cacheReadTokens": 5
                }
              }
            }
          ]
        }
        """

        let report = try parse(json)

        #expect(report.days[0].breakdown["m"]?.totalTokens == 165)
    }

    @Test("breakdown cost falls back to totalCost when costUSD/cost are absent")
    func breakdownCostFallsBackToTotalCost() throws {
        let json = """
        {
          "daily": [
            {
              "date": "2026-05-01",
              "breakdown": {
                "m": { "totalTokens": 10, "totalCost": 4.2 }
              }
            }
          ]
        }
        """

        let report = try parse(json)

        #expect(report.days[0].breakdown["m"]?.costUSD == 4.2)
    }

    @Test("modelBreakdowns entries without a name are skipped")
    func modelBreakdownsWithoutNameSkipped() throws {
        let json = """
        {
          "daily": [
            {
              "date": "2026-05-01",
              "modelBreakdowns": [
                { "inputTokens": 1, "outputTokens": 1 },
                { "modelName": "kept", "inputTokens": 2, "outputTokens": 3 }
              ]
            }
          ]
        }
        """

        let report = try parse(json)

        #expect(report.days[0].breakdown.keys.sorted() == ["kept"])
        #expect(report.days[0].breakdown["kept"]?.totalTokens == 5)
    }

    // MARK: - Summary

    @Test("summary is summed from days when no summary/totals block is present")
    func summaryFallsBackToDaySums() throws {
        let json = """
        {
          "daily": [
            { "date": "2026-05-01", "inputTokens": 10, "outputTokens": 20, "totalTokens": 30, "totalCost": 1.0 },
            { "date": "2026-05-02", "inputTokens": 5, "outputTokens": 5, "totalTokens": 10, "totalCost": 0.5 }
          ]
        }
        """

        let report = try parse(json)

        #expect(report.summary.inputTokens == 15)
        #expect(report.summary.outputTokens == 25)
        #expect(report.summary.totalTokens == 40)
        #expect(report.summary.totalCostUSD == 1.5)
    }

    @Test("summary prefers the total* fields and totalCostUSD over alternates")
    func summaryPrefersTotalFields() throws {
        let json = """
        {
          "daily": [
            { "date": "2026-05-01", "inputTokens": 1, "totalTokens": 1, "totalCost": 0.01 }
          ],
          "summary": {
            "totalInputTokens": 999,
            "inputTokens": 1,
            "totalTokens": 1234,
            "totalCostUSD": 2.0,
            "totalCost": 9.0,
            "costUSD": 8.0
          }
        }
        """

        let report = try parse(json)

        #expect(report.summary.inputTokens == 999)
        #expect(report.summary.totalTokens == 1234)
        #expect(report.summary.totalCostUSD == 2.0)
    }

    // MARK: - blocks duration accounting

    @Test("actualEndTime is preferred over endTime for a block's active span")
    func blocksPreferActualEndTime() throws {
        let json = """
        {
          "blocks": [
            {
              "startTime": "2026-06-10T12:00:00.000Z",
              "endTime": "2026-06-10T18:00:00.000Z",
              "actualEndTime": "2026-06-10T13:00:00.000Z"
            }
          ]
        }
        """

        let activity = try CcusageParser().parseBlocksJSON(Data(json.utf8))

        #expect(activity.values.reduce(0, +) == 3600)
    }

    @Test("a block with no actualEndTime falls back to endTime")
    func blocksFallBackToEndTime() throws {
        let json = """
        {
          "blocks": [
            {
              "startTime": "2026-06-10T12:00:00.000Z",
              "endTime": "2026-06-10T14:00:00.000Z",
              "isActive": true
            }
          ]
        }
        """

        let activity = try CcusageParser().parseBlocksJSON(Data(json.utf8))

        #expect(activity.values.reduce(0, +) == 7200)
    }

    @Test("ISO timestamps without fractional seconds still parse")
    func blocksParsePlainISOTimestamps() throws {
        let json = """
        {
          "blocks": [
            {
              "startTime": "2026-06-10T12:00:00Z",
              "actualEndTime": "2026-06-10T13:00:00Z"
            }
          ]
        }
        """

        let activity = try CcusageParser().parseBlocksJSON(Data(json.utf8))

        #expect(activity.values.reduce(0, +) == 3600)
    }

    @Test("zero-length blocks are skipped")
    func blocksSkipZeroDuration() throws {
        let json = """
        {
          "blocks": [
            {
              "startTime": "2026-06-10T12:00:00.000Z",
              "actualEndTime": "2026-06-10T12:00:00.000Z"
            }
          ]
        }
        """

        let activity = try CcusageParser().parseBlocksJSON(Data(json.utf8))

        #expect(activity.isEmpty)
    }

    @Test("blocks without a start time are skipped")
    func blocksSkipMissingStart() throws {
        let json = """
        {
          "blocks": [
            { "endTime": "2026-06-10T13:00:00.000Z" }
          ]
        }
        """

        let activity = try CcusageParser().parseBlocksJSON(Data(json.utf8))

        #expect(activity.isEmpty)
    }

    @Test("an empty blocks array yields an empty activity map")
    func blocksEmptyArray() throws {
        let activity = try CcusageParser().parseBlocksJSON(Data(#"{"blocks":[]}"#.utf8))
        #expect(activity.isEmpty)
    }
}
