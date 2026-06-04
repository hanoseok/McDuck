import Foundation
import Testing
@testable import McDuckCore

/// Additional coverage for `HeatmapBuilder`: intensity bucket boundaries, cell
/// counts, range guards, the rolling-months window, calendar-year clamping, and
/// the configurable first weekday.
@Suite("usage heatmap builder edge cases")
struct HeatmapBuilderAdditionalTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(DateComponents(calendar: calendar, year: year, month: month, day: day).date)
    }

    // MARK: - Intensity buckets

    @Test("intensity maps token ratios onto four ceil-rounded buckets")
    func intensityBucketBoundaries() throws {
        // Seven consecutive days; max is 1000, so ratio*4 ceils to:
        // 250→1, 251→2, 500→2, 501→3, 750→3, 751→4, 1000→4.
        let end = try date(2026, 5, 7)
        let days = [
            UsageDay.make(date: "2026-05-01", totalTokens: 250),
            UsageDay.make(date: "2026-05-02", totalTokens: 251),
            UsageDay.make(date: "2026-05-03", totalTokens: 500),
            UsageDay.make(date: "2026-05-04", totalTokens: 501),
            UsageDay.make(date: "2026-05-05", totalTokens: 750),
            UsageDay.make(date: "2026-05-06", totalTokens: 751),
            UsageDay.make(date: "2026-05-07", totalTokens: 1000)
        ]

        let cells = HeatmapBuilder(calendar: calendar).build(days: days, endingOn: end, weeks: 1)

        #expect(cells.map(\.intensity) == [1, 2, 2, 3, 3, 4, 4])
    }

    @Test("all-zero usage produces zero intensity everywhere")
    func zeroUsageZeroIntensity() throws {
        let end = try date(2026, 5, 7)
        let days = [
            UsageDay.make(date: "2026-05-06", totalTokens: 0),
            UsageDay.make(date: "2026-05-07", totalTokens: 0)
        ]

        let cells = HeatmapBuilder(calendar: calendar).build(days: days, endingOn: end, weeks: 1)

        #expect(cells.allSatisfy { $0.intensity == 0 })
    }

    // MARK: - Cell counts

    @Test("weeks count drives the number of cells and is clamped to at least one")
    func weeksCountAndClamp() throws {
        let end = try date(2026, 5, 7)
        let builder = HeatmapBuilder(calendar: calendar)

        #expect(builder.build(days: [], endingOn: end, weeks: 2).count == 14)
        // weeks <= 0 is clamped up to a single week.
        #expect(builder.build(days: [], endingOn: end, weeks: 0).count == 7)
    }

    // MARK: - Range guard

    @Test("a reversed range returns no cells")
    func reversedRangeReturnsEmpty() throws {
        let start = try date(2026, 5, 10)
        let end = try date(2026, 5, 1)

        let cells = HeatmapBuilder(calendar: calendar).build(days: [], rangeStart: start, rangeEnd: end)

        #expect(cells.isEmpty)
    }

    // MARK: - Rolling window

    @Test("recentMonths ends on today, is week-aligned, and starts one month + a day back")
    func recentMonthsWindow() throws {
        let today = try date(2026, 6, 4)
        let cells = HeatmapBuilder(calendar: calendar).recentMonths(days: [], months: 1, endingOn: today)
        let inRange = cells.filter { !$0.isPlaceholder }

        #expect(cells.count % 7 == 0)
        #expect(inRange.first?.dateString == "2026-05-05")
        #expect(inRange.last?.dateString == "2026-06-04")
    }

    // MARK: - Calendar year

    @Test("a fully elapsed year spans Jan 1 through Dec 31")
    func fullyElapsedYear() throws {
        let today = try date(2026, 6, 4)
        let cells = HeatmapBuilder(calendar: calendar).year(days: [], year: 2024, today: today)
        let inRange = cells.filter { !$0.isPlaceholder }

        #expect(inRange.first?.dateString == "2024-01-01")
        #expect(inRange.last?.dateString == "2024-12-31")
    }

    @Test("a future year (entirely past today) yields no cells")
    func futureYearIsEmpty() throws {
        let today = try date(2026, 6, 4)
        let cells = HeatmapBuilder(calendar: calendar).year(days: [], year: 2030, today: today)

        #expect(cells.isEmpty)
    }

    // MARK: - First weekday

    @Test("firstWeekday controls where each grid week begins")
    func firstWeekdayShiftsGrid() throws {
        // 2026-05-07 is a Thursday. A Monday-first grid starts its week on 05-04;
        // the default Sunday-first grid would start on 05-03.
        let day = try date(2026, 5, 7)
        let builder = HeatmapBuilder(calendar: calendar)

        let mondayFirst = builder.build(days: [], rangeStart: day, rangeEnd: day, firstWeekday: 2)
        #expect(mondayFirst.count == 7)
        #expect(mondayFirst.first?.dateString == "2026-05-04")
        #expect(mondayFirst.last?.dateString == "2026-05-10")

        let sundayFirst = builder.build(days: [], rangeStart: day, rangeEnd: day, firstWeekday: 1)
        #expect(sundayFirst.first?.dateString == "2026-05-03")
    }
}

private extension UsageDay {
    static func make(date: String, totalTokens: Int) -> UsageDay {
        UsageDay(
            dateString: date,
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalTokens: totalTokens,
            costUSD: 0,
            models: [],
            breakdown: [:]
        )
    }
}
