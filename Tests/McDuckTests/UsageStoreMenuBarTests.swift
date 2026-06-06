import Foundation
import Testing
import McDuckCore
@testable import McDuck

/// Regression coverage for the menu-bar label usage derived per period.
@Suite("usage store menu bar period")
@MainActor
struct UsageStoreMenuBarTests {
    private func day(offset: Int, tokens: Int, cost: Double) -> UsageDay {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
        return UsageDay(
            dateString: DateOnly.string(from: date),
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalTokens: tokens,
            costUSD: cost,
            models: [],
            breakdown: [:]
        )
    }

    /// today=100/$1, -3d=200/$2 (within week), -10d=300/$3 (within month),
    /// -40d=999/$9 (only in total).
    private func loadedStore() -> UsageStore {
        let days = [
            day(offset: 0, tokens: 100, cost: 1.0),
            day(offset: -3, tokens: 200, cost: 2.0),
            day(offset: -10, tokens: 300, cost: 3.0),
            day(offset: -40, tokens: 999, cost: 9.0)
        ]
        let summary = UsageSummary(inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, totalTokens: 1599, totalCostUSD: 15.0)
        let store = UsageStore()
        store.phase = .loaded(UsageStore.DashboardData(report: UsageReport(days: days, summary: summary)))
        return store
    }

    @Test("none shows nothing")
    func noneIsNil() {
        #expect(loadedStore().menuBarUsage(for: .none) == nil)
    }

    @Test("today sums only today")
    func today() {
        let usage = loadedStore().menuBarUsage(for: .today)
        #expect(usage?.tokens == Formatters.compact(100))
        #expect(usage?.cost == Formatters.currency(1.0))
    }

    @Test("week sums the last 7 days")
    func week() {
        // today (100) + 3 days ago (200) = 300; 10 and 40 days ago excluded.
        #expect(loadedStore().menuBarUsage(for: .week)?.tokens == Formatters.compact(300))
    }

    @Test("month sums roughly the last month")
    func month() {
        // today + 3d + 10d = 600; 40 days ago excluded.
        #expect(loadedStore().menuBarUsage(for: .month)?.tokens == Formatters.compact(600))
    }

    @Test("total sums all history")
    func total() {
        let usage = loadedStore().menuBarUsage(for: .total)
        // 100+200+300+999 tokens, $1+$2+$3+$9 cost.
        #expect(usage?.tokens == Formatters.compact(1599))
        #expect(usage?.cost == Formatters.currency(15.0))
    }

    @Test("no data shows nothing even for total")
    func noDataIsNil() {
        let store = UsageStore()
        #expect(store.menuBarUsage(for: .total) == nil)
        #expect(store.menuBarUsage(for: .today) == nil)
    }
}
