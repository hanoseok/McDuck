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

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task { await store.refresh(quiet: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isInstalling || store.isRefreshing)
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
                .frame(height: 120)
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
                    HeatmapGrid(
                        cells: store.heatmapCells,
                        selectedDateString: $store.selectedDateString,
                        scrollAnchor: store.selectedYear == nil ? .trailing : .leading
                    )
                    .id(store.selectedYear)
                    YearSelector(years: store.availableYears, selectedYear: $store.selectedYear)
                }
            }
            .padding(12)
            .mcDuckGlass(cornerRadius: 14)

            if let selectedDay = store.selectedDay {
                UsageDetailView(
                    day: selectedDay,
                    activity: store.dailyActivity[selectedDay.dateString]
                )
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
                    PopoverDatePicker(date: $store.customStart)
                    Text("–")
                        .foregroundStyle(.secondary)
                    PopoverDatePicker(date: $store.customEnd)
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
            MetricPill(title: "Cost", value: Formatters.currency(store.rangeSummary.totalCostUSD))
            MetricPill(title: "Time", value: store.rangeActiveTimeText)
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

/// A date control that opens a calendar in a popover, avoiding the inline
/// stepper field whose selected digit keeps a lingering blue highlight.
private struct PopoverDatePicker: View {
    @Binding var date: Date
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Text(date, format: .dateTime.year().month(.abbreviated).day())
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .popover(isPresented: $isPresented) {
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(10)
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

    @State private var hoveredDay: Date?

    private struct Segment: Identifiable {
        var id: String { "\(date.timeIntervalSince1970)-\(model)" }
        let date: Date
        let model: String
        let tokens: Int
    }

    /// One stacked segment per (day, model) so each bar shows the day total and
    /// the per-model proportion within it.
    private var segments: [Segment] {
        days.flatMap { day -> [Segment] in
            if day.breakdown.isEmpty {
                return [Segment(date: day.date, model: "Total", tokens: day.totalTokens)]
            }
            return day.breakdown.map { entry in
                Segment(date: day.date, model: entry.key, tokens: entry.value.totalTokens)
            }
        }
    }

    private var segmentsByDay: [Date: [Segment]] {
        Dictionary(grouping: segments) { Calendar(identifier: .gregorian).startOfDay(for: $0.date) }
    }

    var body: some View {
        Chart {
            ForEach(segments) { segment in
                BarMark(
                    x: .value("Date", segment.date, unit: .day),
                    y: .value("Tokens", segment.tokens)
                )
                .foregroundStyle(by: .value("Model", segment.model))
            }

            if let hoveredDay, let items = segmentsByDay[hoveredDay] {
                RuleMark(x: .value("Date", hoveredDay, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .annotation(
                        position: .top,
                        spacing: 0,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        tooltip(date: hoveredDay, items: items)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let tokens = value.as(Int.self) {
                        Text(tokens.formatted(.number.notation(.compactName)))
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredDay = day(at: location, proxy: proxy, geo: geo)
                        case .ended:
                            hoveredDay = nil
                        }
                    }
            }
        }
        .accessibilityLabel("Token usage by model and day")
    }

    private func day(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Date? {
        guard let plotFrame = proxy.plotFrame else {
            return nil
        }
        let xInPlot = location.x - geo[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: xInPlot) else {
            return nil
        }
        let startOfDay = Calendar(identifier: .gregorian).startOfDay(for: date)
        return segmentsByDay[startOfDay] != nil ? startOfDay : nil
    }

    private func tooltip(date: Date, items: [Segment]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(date, format: .dateTime.year().month().day())
                .font(.caption2.weight(.semibold))

            ForEach(items.sorted { $0.tokens > $1.tokens }) { item in
                HStack(spacing: 10) {
                    Text(item.model)
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                    Text(Formatters.compact(item.tokens))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 150, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.secondary.opacity(0.25))
        }
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
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

