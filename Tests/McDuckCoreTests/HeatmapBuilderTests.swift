import Foundation
import Testing
@testable import McDuckCore

@Suite("usage heatmap builder")
struct HeatmapBuilderTests {
    @Test("builds date ordered cells and token intensity buckets")
    func buildsDateOrderedCellsAndIntensityBuckets() throws {
        let calendar = Calendar(identifier: .gregorian)
        let endDate = try #require(DateComponents(calendar: calendar, year: 2026, month: 5, day: 7).date)
        let days = [
            UsageDay.make(date: "2026-05-01", totalTokens: 100),
            UsageDay.make(date: "2026-05-03", totalTokens: 500),
            UsageDay.make(date: "2026-05-07", totalTokens: 1_000)
        ]

        let cells = HeatmapBuilder(calendar: calendar).build(days: days, endingOn: endDate, weeks: 1)

        #expect(cells.map(\.dateString) == [
            "2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04",
            "2026-05-05", "2026-05-06", "2026-05-07"
        ])
        #expect(cells[0].intensity == 1)
        #expect(cells[1].intensity == 0)
        #expect(cells[2].intensity == 2)
        #expect(cells[6].intensity == 4)
    }

    @Test("range build pads to whole weeks with leading placeholders")
    func rangeBuildPadsToWholeWeeks() throws {
        let calendar = Calendar(identifier: .gregorian)
        // 2026-05-06 is a Wednesday; 2026-05-08 is a Friday.
        let start = try #require(DateComponents(calendar: calendar, year: 2026, month: 5, day: 6).date)
        let end = try #require(DateComponents(calendar: calendar, year: 2026, month: 5, day: 8).date)
        let days = [UsageDay.make(date: "2026-05-07", totalTokens: 500)]

        let cells = HeatmapBuilder(calendar: calendar).build(days: days, rangeStart: start, rangeEnd: end)

        // Padded out to a whole Sun..Sat week.
        #expect(cells.count == 7)
        #expect(cells.first?.dateString == "2026-05-03") // Sunday before the range
        #expect(cells.last?.dateString == "2026-05-09")  // Saturday after the range
        // Leading/trailing days outside [start, end] are placeholders.
        #expect(cells[0].isPlaceholder == true)  // 05-03, before start
        #expect(cells[3].isPlaceholder == false) // 05-06, in range
        #expect(cells[6].isPlaceholder == true)  // 05-09, after end
        // The day with usage keeps its intensity.
        #expect(cells.first(where: { $0.dateString == "2026-05-07" })?.intensity == 4)
    }

    @Test("year build is clamped to today and starts on Jan 1")
    func yearBuildClampedToToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(DateComponents(calendar: calendar, year: 2026, month: 6, day: 4).date)
        let days = [UsageDay.make(date: "2026-03-15", totalTokens: 100)]

        let cells = HeatmapBuilder(calendar: calendar).year(days: days, year: 2026, today: today)
        let inRange = cells.filter { !$0.isPlaceholder }

        #expect(inRange.first?.dateString == "2026-01-01")
        #expect(inRange.last?.dateString == "2026-06-04") // clamped to today, no future
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
