import Foundation
import Testing
import McDuckCore
@testable import McDuck

/// Regression coverage for the menu-bar label text derived from today's usage.
@Suite("usage store menu bar text")
@MainActor
struct UsageStoreMenuBarTests {
    /// Builds a store whose loaded report contains a single day for *today*
    /// (the day the menu-bar label reads from).
    private func loadedStore(cost: Double, tokens: Int) -> UsageStore {
        let today = DateOnly.string(from: Date())
        let day = UsageDay(
            dateString: today,
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalTokens: tokens,
            costUSD: cost,
            models: [],
            breakdown: [:]
        )
        let summary = UsageSummary(
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalTokens: tokens,
            totalCostUSD: cost
        )
        let store = UsageStore()
        store.phase = .loaded(UsageStore.DashboardData(report: UsageReport(days: [day], summary: summary)))
        return store
    }

    @Test("menu bar text formats today's cost and tokens")
    func formatsTodaysUsage() {
        let store = loadedStore(cost: 3.21, tokens: 1500)
        #expect(store.menuBarCostText == Formatters.currency(3.21))
        #expect(store.menuBarTokensText == Formatters.compact(1500))
    }

    @Test("menu bar text is nil before any data has loaded")
    func nilWithoutData() {
        let store = UsageStore()
        #expect(store.menuBarCostText == nil)
        #expect(store.menuBarTokensText == nil)
    }

    @Test("menu bar text is nil when today has no usage day")
    func nilWhenTodayMissing() {
        // Loaded, but the only day is in the past — not today.
        let day = UsageDay(
            dateString: "2000-01-01",
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalTokens: 999,
            costUSD: 9.99,
            models: [],
            breakdown: [:]
        )
        let summary = UsageSummary(
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalTokens: 999,
            totalCostUSD: 9.99
        )
        let store = UsageStore()
        store.phase = .loaded(UsageStore.DashboardData(report: UsageReport(days: [day], summary: summary)))

        #expect(store.menuBarCostText == nil)
        #expect(store.menuBarTokensText == nil)
    }
}
