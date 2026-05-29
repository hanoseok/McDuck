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
        let cells: [HeatmapCell]
    }

    private let client: CcusageClient
    private let heatmapBuilder: HeatmapBuilder

    var phase: Phase = .idle
    var selectedDateString: String?
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
            let cells = heatmapBuilder.build(days: report.days, weeks: 12)
            phase = .loaded(DashboardData(report: report, cells: cells))
            lastUpdated = Date()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}
