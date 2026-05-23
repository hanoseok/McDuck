import Charts
import McDuckCore
import SwiftUI

struct McDuckPopover: View {
    @Bindable var store: UsageStore

    var body: some View {
        McDuckGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                header
                content
                footer
            }
            .padding(16)
        }
        .background(.windowBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .mcDuckGlass(cornerRadius: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text("McDuck")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isInstalling)
            .help("Refresh")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle, .loading:
            loadingView
        case .setup(let requirement):
            SetupView(
                requirement: requirement,
                isInstalling: store.isInstalling,
                log: store.setupLog
            ) {
                Task { await store.performSetup() }
            }
        case .loaded(let dashboard):
            loadedView(dashboard)
        case .empty:
            messageView(
                title: "No usage yet",
                message: "ccusage did not return daily usage data."
            )
        case .error(let message):
            errorView(message)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading usage")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .mcDuckGlass()
    }

    private func loadedView(_ dashboard: UsageStore.DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryStrip(dashboard.report)

            TokenBarChart(days: Array(dashboard.report.days.suffix(14)))
                .frame(height: 58)
                .padding(12)
                .mcDuckGlass(cornerRadius: 14)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Daily usage")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Last 12 weeks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HeatmapGrid(cells: dashboard.cells, selectedDateString: $store.selectedDateString)
            }
            .padding(12)
            .mcDuckGlass(cornerRadius: 14)

            if let selectedDay = store.selectedDay {
                UsageDetailView(day: selectedDay)
            }
        }
    }

    private func summaryStrip(_ report: UsageReport) -> some View {
        HStack(spacing: 8) {
            MetricPill(title: "Tokens", value: Formatters.compact(report.summary.totalTokens))
            MetricPill(title: "Cost", value: Formatters.currency(report.summary.totalCostUSD))
            MetricPill(title: "Days", value: "\(report.days.count)")
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            messageView(title: "Could not load usage", message: message)
            Button {
                Task { await store.refresh() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }
        .padding(12)
        .mcDuckGlass()
    }

    private func messageView(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .mcDuckGlass()
    }

    private var footer: some View {
        HStack {
            if let lastUpdated = store.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit McDuck")
        }
    }

    private var statusText: String {
        switch store.phase {
        case .idle:
            "Ready"
        case .loading:
            "Checking ccusage"
        case .setup:
            "Setup required"
        case .loaded:
            "Token usage"
        case .empty:
            "No usage found"
        case .error:
            "Needs attention"
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .mcDuckGlass(cornerRadius: 12)
    }
}

private struct TokenBarChart: View {
    let days: [UsageDay]

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Date", day.date),
                y: .value("Tokens", day.totalTokens)
            )
            .foregroundStyle(.blue.gradient)
            .cornerRadius(3)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityLabel("Recent token usage bar chart")
    }
}
