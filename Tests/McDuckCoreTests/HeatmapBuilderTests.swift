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
