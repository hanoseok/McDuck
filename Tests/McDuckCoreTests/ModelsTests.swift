import Foundation
import Testing
@testable import McDuckCore

/// Covers the value models and the internal `DateOnly` helper: date parsing,
/// round-tripping, derived fields, and identifiers.
@Suite("models and date helpers")
struct ModelsTests {
    // MARK: - DateOnly

    @Test("DateOnly parses and round-trips an ISO calendar date")
    func dateOnlyRoundTrips() throws {
        let date = try #require(DateOnly.parse("2026-05-20"))
        #expect(DateOnly.string(from: date) == "2026-05-20")
    }

    @Test("DateOnly rejects malformed and out-of-range dates")
    func dateOnlyRejectsInvalid() {
        // Note: the underlying DateFormatter rolls overflowing day components
        // forward (e.g. Feb 30 -> Mar 2), so only structurally invalid strings
        // are guaranteed to return nil.
        #expect(DateOnly.parse("not-a-date") == nil)
        #expect(DateOnly.parse("2026-13-01") == nil) // month out of range
        #expect(DateOnly.parse("") == nil)
    }

    // MARK: - UsageDay

    @Test("UsageDay derives its date from the date string")
    func usageDayDerivesDate() throws {
        let day = UsageDay.make(date: "2026-05-20")
        #expect(day.date == DateOnly.parse("2026-05-20"))
    }

    @Test("UsageDay falls back to distantPast for an unparseable date string")
    func usageDayInvalidDateFallsBack() {
        let day = UsageDay.make(date: "garbage")
        #expect(day.date == .distantPast)
    }

    @Test("UsageDay is identified by its date string")
    func usageDayIdentity() {
        let day = UsageDay.make(date: "2026-05-20")
        #expect(day.id == "2026-05-20")
    }

    // MARK: - HeatmapCell

    @Test("HeatmapCell is identified by its date string and defaults to a non-placeholder")
    func heatmapCellIdentity() throws {
        let date = try #require(DateOnly.parse("2026-05-20"))
        let cell = HeatmapCell(date: date, dateString: "2026-05-20", day: nil, intensity: 0)

        #expect(cell.id == "2026-05-20")
        #expect(cell.isPlaceholder == false)
    }

    // MARK: - Equatable value semantics

    @Test("ModelUsage equates by all stored fields")
    func modelUsageEquatable() {
        let a = ModelUsage(inputTokens: 1, outputTokens: 2, cacheCreationTokens: 3, cacheReadTokens: 4, totalTokens: 10, costUSD: 0.5)
        let b = ModelUsage(inputTokens: 1, outputTokens: 2, cacheCreationTokens: 3, cacheReadTokens: 4, totalTokens: 10, costUSD: 0.5)
        let c = ModelUsage(inputTokens: 9, outputTokens: 2, cacheCreationTokens: 3, cacheReadTokens: 4, totalTokens: 10, costUSD: 0.5)

        #expect(a == b)
        #expect(a != c)
    }

    @Test("UsageReport equates by its days and summary")
    func usageReportEquatable() {
        let summary = UsageSummary(inputTokens: 1, outputTokens: 1, cacheCreationTokens: 0, cacheReadTokens: 0, totalTokens: 2, totalCostUSD: 0.1)
        let report1 = UsageReport(days: [UsageDay.make(date: "2026-05-20")], summary: summary)
        let report2 = UsageReport(days: [UsageDay.make(date: "2026-05-20")], summary: summary)

        #expect(report1 == report2)
    }
}

private extension UsageDay {
    static func make(date: String) -> UsageDay {
        UsageDay(
            dateString: date,
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalTokens: 0,
            costUSD: 0,
            models: [],
            breakdown: [:]
        )
    }
}
