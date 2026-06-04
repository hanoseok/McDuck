import Charts
import McDuckCore
import SwiftUI

struct McDuckPopover: View {
    @Bindable var store: UsageStore

    var body: some View {
        McDuckGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                header
                CappedScroll(maxHeight: 600) {
                    content
                }
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
        case .loaded:
            loadedView()
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

    private func loadedView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            rangeControls

            summaryStrip

            TokenBarChart(days: store.filteredDays)
                .frame(height: 58)
                .padding(12)
                .mcDuckGlass(cornerRadius: 14)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Daily usage")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(store.heatmapRangeTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 10) {
                    HeatmapGrid(cells: store.heatmapCells, selectedDateString: $store.selectedDateString)
                    YearSelector(years: store.availableYears, selectedYear: $store.selectedYear)
                }
            }
            .padding(12)
            .mcDuckGlass(cornerRadius: 14)

            if let selectedDay = store.selectedDay {
                UsageDetailView(day: selectedDay)
            }
        }
    }

    private var rangeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $store.rangeMode) {
                ForEach(UsageStore.RangeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 8) {
                if store.rangeMode == .custom {
                    DatePicker("", selection: $store.customStart, displayedComponents: .date)
                        .labelsHidden()
                    Text("–")
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $store.customEnd, displayedComponents: .date)
                        .labelsHidden()
                }

                Spacer()

                Text(store.rangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 8) {
            MetricPill(title: "Tokens", value: Formatters.compact(store.rangeSummary.totalTokens))
            MetricPill(title: "Days", value: "\(store.rangeActiveDays)")
            MetricPill(title: "Cost", value: Formatters.currency(store.rangeSummary.totalCostUSD))
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

/// GitHub-style year picker. No explicit "Recent" entry: when no year is
/// selected the heatmap shows the rolling last-12-months view. Tapping the
/// selected year again clears the selection back to that default.
private struct YearSelector: View {
    let years: [Int]
    @Binding var selectedYear: Int?

    var body: some View {
        VStack(spacing: 4) {
            ForEach(years, id: \.self) { year in
                chip(year)
            }
        }
        .frame(width: 40)
    }

    private func chip(_ year: Int) -> some View {
        let isSelected = selectedYear == year
        return Button {
            selectedYear = isSelected ? nil : year
        } label: {
            chipLabel(year, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chipLabel(_ year: Int, isSelected: Bool) -> some View {
        let label = Text(String(year))
            .font(.caption2.weight(isSelected ? .semibold : .regular))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundStyle(isSelected ? Color.white : Color.primary)

        if isSelected {
            label.background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor)
            }
        } else {
            label.mcDuckGlass(cornerRadius: 6)
        }
    }
}

private struct HeatmapHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Vertically scrolls its content only when it would exceed `maxHeight`,
/// otherwise sizes to fit so the popover doesn't leave empty space.
private struct CappedScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            content
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: HeatmapHeightKey.self, value: proxy.size.height)
                    }
                )
        }
        .frame(height: min(contentHeight == 0 ? maxHeight : contentHeight, maxHeight))
        .onPreferenceChange(HeatmapHeightKey.self) { contentHeight = $0 }
    }
}
