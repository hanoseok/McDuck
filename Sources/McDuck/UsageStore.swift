import Foundation
import McDuckCore
import Observation

@MainActor
@Observable
final class UsageStore {
    enum Phase: Equatable {
        case idle
        case loading
        case setup(SetupRequirement)
        case loaded(DashboardData)
        case empty
        case error(String)
    }

    enum SetupRequirement: Equatable {
        case missingBun
        case missingCcusage(String)

        var title: String {
            switch self {
            case .missingBun:
                "Bun is required"
            case .missingCcusage:
                "ccusage is not ready"
            }
        }

        var message: String {
            switch self {
            case .missingBun:
                "Install Bun to let McDuck run ccusage locally."
            case .missingCcusage(let detail):
                detail.isEmpty ? "Run setup to download and cache ccusage through bunx." : detail
            }
        }

        var actionTitle: String {
            switch self {
            case .missingBun:
                "Install Bun"
            case .missingCcusage:
                "Install ccusage"
            }
        }
    }

    struct DashboardData: Equatable {
        let report: UsageReport
    }

    /// Time window for the top summary + bar chart (does NOT affect the heatmap).
    enum RangeMode: String, CaseIterable, Identifiable {
        case week
        case month
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .week: "1W"
            case .month: "1M"
            case .custom: "Custom"
            }
        }
    }

    private let client: CcusageClient
    private let heatmapBuilder: HeatmapBuilder

    /// Earliest year offered in the heatmap year selector.
    static let earliestYear = 2023

    var phase: Phase = .idle
    var selectedDateString: String?
    /// nil = rolling "recent 12 months" view; otherwise a specific calendar year.
    var selectedYear: Int?
    /// Active window for the summary strip and bar chart.
    var rangeMode: RangeMode = .month
    var customStart: Date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -7, to: Date()) ?? Date()
    var customEnd: Date = Date()
    var isInstalling = false
    var setupLog: String?
    var lastUpdated: Date?

    init(
        client: CcusageClient = CcusageClient(),
        heatmapBuilder: HeatmapBuilder = HeatmapBuilder()
    ) {
        self.client = client
        self.heatmapBuilder = heatmapBuilder
    }

    var dashboard: DashboardData? {
        if case .loaded(let dashboard) = phase {
            dashboard
        } else {
            nil
        }
    }

    /// Years offered in the selector, newest first, from the current year back to `earliestYear`.
    var availableYears: [Int] {
        let current = Calendar(identifier: .gregorian).component(.year, from: Date())
        guard current >= Self.earliestYear else {
            return [current]
        }
        return Array(stride(from: current, through: Self.earliestYear, by: -1))
    }

    /// Heatmap cells for the active selection (recent 12 months, or a chosen year).
    var heatmapCells: [HeatmapCell] {
        guard let report = dashboard?.report else {
            return []
        }

        if let year = selectedYear {
            return heatmapBuilder.year(days: report.days, year: year)
        }

        return heatmapBuilder.recentMonths(days: report.days, months: 12)
    }

    var heatmapRangeTitle: String {
        if let year = selectedYear {
            return String(year)
        }
        return "Last 12 months"
    }

    // MARK: - Summary range (top + graph)

    private var gregorian: Calendar { Calendar(identifier: .gregorian) }

    /// Inclusive [start, end] day window for the active range mode.
    var rangeInterval: (start: Date, end: Date) {
        let today = gregorian.startOfDay(for: Date())
        switch rangeMode {
        case .week:
            let start = gregorian.date(byAdding: .day, value: -6, to: today) ?? today
            return (start, today)
        case .month:
            let back = gregorian.date(byAdding: .month, value: -1, to: today) ?? today
            let start = gregorian.date(byAdding: .day, value: 1, to: back) ?? back
            return (start, today)
        case .custom:
            let start = gregorian.startOfDay(for: min(customStart, customEnd))
            let end = gregorian.startOfDay(for: max(customStart, customEnd))
            return (start, end)
        }
    }

    /// Usage days that fall within the active range.
    var filteredDays: [UsageDay] {
        guard let report = dashboard?.report else {
            return []
        }
        let (start, end) = rangeInterval
        return report.days.filter { day in
            let date = gregorian.startOfDay(for: day.date)
            return date >= start && date <= end
        }
    }

    /// Aggregated totals for the active range.
    var rangeSummary: UsageSummary {
        let days = filteredDays
        return UsageSummary(
            inputTokens: days.reduce(0) { $0 + $1.inputTokens },
            outputTokens: days.reduce(0) { $0 + $1.outputTokens },
            cacheCreationTokens: days.reduce(0) { $0 + $1.cacheCreationTokens },
            cacheReadTokens: days.reduce(0) { $0 + $1.cacheReadTokens },
            totalTokens: days.reduce(0) { $0 + $1.totalTokens },
            totalCostUSD: days.reduce(0) { $0 + $1.costUSD }
        )
    }

    /// Number of days with usage inside the active range.
    var rangeActiveDays: Int {
        filteredDays.count
    }

    var rangeLabel: String {
        let (start, end) = rangeInterval
        return "\(Self.rangeFormatter.string(from: start)) – \(Self.rangeFormatter.string(from: end))"
    }

    private static let rangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var selectedDay: UsageDay? {
        guard let report = dashboard?.report else {
            return nil
        }

        if let selectedDateString,
           let day = report.days.first(where: { $0.dateString == selectedDateString }) {
            return day
        }

        return report.days.last
    }

    func refreshIfNeeded() async {
        guard phase == .idle else {
            return
        }

        await refresh()
    }

    func refresh() async {
        phase = .loading
        setupLog = nil

        switch await client.checkDependencies() {
        case .missingBun:
            phase = .setup(.missingBun)
        case .ccusageUnavailable(_, let message):
            phase = .setup(.missingCcusage(message))
        case .ready:
            await loadUsage()
        }
    }

    func performSetup() async {
        guard !isInstalling else {
            return
        }

        isInstalling = true
        defer { isInstalling = false }

        let result: CommandResult
        switch phase {
        case .setup(.missingBun):
            setupLog = "Installing Bun..."
            result = await client.installBun()
        case .setup(.missingCcusage):
            setupLog = "Installing ccusage through bunx..."
            result = await client.bootstrapCcusage()
        default:
            return
        }

        if result.exitCode == 0 {
            setupLog = "Setup complete."
            await refresh()
        } else {
            let message = (result.stderr.isEmpty ? result.stdout : result.stderr)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            phase = .error(message.isEmpty ? "Setup failed." : message)
        }
    }

    private func loadUsage() async {
        do {
            let report = try await client.loadDailyReport()
            guard !report.days.isEmpty else {
                phase = .empty
                return
            }

            selectedDateString = selectedDateString ?? report.days.last?.dateString
            phase = .loaded(DashboardData(report: report))
            lastUpdated = Date()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}
