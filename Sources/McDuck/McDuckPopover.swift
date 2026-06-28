import Charts
import McDuckCore
import SwiftUI

struct McDuckPopover: View {
    @Bindable var store: UsageStore
    @Bindable var settings: SettingsStore

    @State private var isSettingsPresented = false

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
            Group {
                if let icon = AppImages.titleIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                } else {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.tint)
                }
            }
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
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .mcDuckGlassButton()
            .controlSize(.small)
            .help("Settings")
            .popover(isPresented: $isSettingsPresented, arrowEdge: .top) {
                SettingsView(settings: settings)
            }
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
                log: store.setupLog,
                action: {
                    if requirement.isMissingBun {
                        // No Bun: send the user to bun.com to install it themselves.
                        if let url = URL(string: "https://bun.com") {
                            NSWorkspace.shared.open(url)
                        }
                    } else {
                        Task { await store.performSetup() }
                    }
                },
                secondaryTitle: requirement.isMissingBun ? "Recheck" : nil,
                secondaryAction: requirement.isMissingBun ? { Task { await store.refresh() } } : nil
            )
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

                YearSelector(years: store.availableYears, selectedYear: $store.selectedYear)

                HeatmapGrid(
                    cells: store.heatmapCells,
                    selectedDateString: Binding(
                        get: { store.effectiveSelectedDateString },
                        set: { store.selectedDateString = $0 }
                    ),
                    scrollAnchor: store.selectedYear == nil ? .trailing : .leading
                )
                .id(store.selectedYear)
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
            .mcDuckGlassButton()
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
        HStack(spacing: 8) {
            if let lastUpdated = store.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await store.refresh(quiet: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .mcDuckGlassButton()
            .controlSize(.small)
            .disabled(store.isInstalling || store.isRefreshing)
            .help("Reload usage")
            .accessibilityLabel("Reload usage")

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Text(Self.appVersion)
                .font(.caption2)
                .foregroundStyle(.secondary)

            updateFooterButton
        }
    }

    @ViewBuilder
    private var updateFooterButton: some View {
        if let availableUpdate = settings.availableUpdate {
            if settings.isInstallingUpdate {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task { await settings.installAvailableUpdate() }
                } label: {
                    Label("Update", systemImage: "arrow.down.circle")
                }
                .mcDuckGlassButton(prominent: true)
                .tint(.blue)
                .controlSize(.small)
                .help("Install McDuck \(availableUpdate.version.description)")
            }
        }
    }

    /// App version from the bundle (stamped at build time), e.g. "v0.0.15".
    private static var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        guard let short, !short.isEmpty else {
            return "dev"
        }
        return "v\(short)"
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
        .mcDuckGlassButton()
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
    @State private var tooltipAnchor: CGPoint?
    @State private var isTooltipHovered = false
    @State private var clearHoverTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme

    private static let modelPalette: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .pink,
        .teal,
        .indigo,
        .mint,
        .red,
        .yellow
    ]
    private static let legendColumnCount = 2
    private static let legendMaxRowCount = 3
    private static let legendRowHeight: CGFloat = 14
    private static let legendVerticalPadding: CGFloat = 4
    private static let legendColumnSpacing: CGFloat = 8
    private static let tooltipBarGap: CGFloat = 8
    private static let tooltipRowsMaxHeight: CGFloat = 56

    /// A fully opaque, fixed RGB color (not a system/dynamic color). System
    /// colors render with vibrancy inside the menu-bar popover, which is why the
    /// tooltip looked see-through; a literal color stays solid.
    private var tooltipBackground: Color {
        colorScheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.17) : .white
    }

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

    private var modelTotals: [(model: String, tokens: Int)] {
        let totals = segments.reduce(into: [String: Int]()) { result, segment in
            result[segment.model, default: 0] += segment.tokens
        }

        return totals
            .map { (model: $0.key, tokens: $0.value) }
            .sorted {
                if $0.tokens == $1.tokens {
                    return $0.model < $1.model
                }
                return $0.tokens > $1.tokens
            }
    }

    private var modelDomain: [String] {
        modelTotals.map(\.model)
    }

    private var modelColors: [Color] {
        modelDomain.indices.map { Self.modelPalette[$0 % Self.modelPalette.count] }
    }

    private var legendVisibleRowCount: Int {
        let rowCount = (modelDomain.count + Self.legendColumnCount - 1) / Self.legendColumnCount
        return min(Self.legendMaxRowCount, max(1, rowCount))
    }

    private var legendColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Self.legendColumnSpacing, alignment: .leading),
            count: Self.legendColumnCount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !modelDomain.isEmpty {
                modelLegend
            }

            chartBody
                .frame(height: 120)
                .overlay(alignment: .topLeading) {
                    floatingTooltip
                }
        }
        .accessibilityLabel("Token usage by model and day")
    }

    @ViewBuilder
    private var floatingTooltip: some View {
        if let hoveredDay, let items = segmentsByDay[hoveredDay], let tooltipAnchor {
            let tooltipBarGap = Self.tooltipBarGap
            tooltip(date: hoveredDay, items: items)
                .alignmentGuide(.leading) { dimensions in
                    dimensions[HorizontalAlignment.center] - tooltipAnchor.x
                }
                .alignmentGuide(.top) { dimensions in
                    dimensions[VerticalAlignment.bottom] - tooltipAnchor.y + tooltipBarGap
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        isTooltipHovered = true
                        clearHoverTask?.cancel()
                        clearHoverTask = nil
                    case .ended:
                        clearHover()
                    }
                }
                .zIndex(1)
        }
    }

    private var chartBody: some View {
        Chart {
            ForEach(segments) { segment in
                BarMark(
                    x: .value("Date", segment.date, unit: .day),
                    y: .value("Tokens", segment.tokens)
                )
                .foregroundStyle(by: .value("Model", segment.model))
            }

            if let hoveredDay {
                RuleMark(x: .value("Date", hoveredDay, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.35))
            }
        }
        .chartForegroundStyleScale(domain: modelDomain, range: modelColors)
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
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            updateHover(at: location, proxy: proxy, geo: geo)
                        case .ended:
                            clearHoverAfterTooltipOpportunity()
                        }
                    }
            }
        }
        .accessibilityLabel("Token usage by model and day")
    }

    private var modelLegend: some View {
        ScrollView(.vertical, showsIndicators: modelDomain.count > Self.legendColumnCount * Self.legendMaxRowCount) {
            LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 4) {
                ForEach(modelDomain, id: \.self) { model in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(modelColor(for: model))
                            .frame(width: 7, height: 7)

                        Text(model)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, minHeight: Self.legendRowHeight, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: Self.legendRowHeight * CGFloat(legendVisibleRowCount) + Self.legendVerticalPadding)
    }

    private func updateHover(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let nextDay = day(at: location, proxy: proxy, geo: geo)
        let nextAnchor = nextDay.flatMap { tooltipAnchor(for: $0, proxy: proxy, geo: geo) }
        guard nextDay != hoveredDay else { return }
        clearHoverTask?.cancel()
        clearHoverTask = nil
        isTooltipHovered = false
        hoveredDay = nextDay
        tooltipAnchor = nextAnchor
    }

    private func clearHoverAfterTooltipOpportunity() {
        clearHoverTask?.cancel()
        clearHoverTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled, !isTooltipHovered else { return }
            clearHover()
        }
    }

    private func clearHover() {
        clearHoverTask?.cancel()
        clearHoverTask = nil
        hoveredDay = nil
        tooltipAnchor = nil
        isTooltipHovered = false
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

    private func tooltipAnchor(for day: Date, proxy: ChartProxy, geo: GeometryProxy) -> CGPoint? {
        guard let plotFrame = proxy.plotFrame,
              let x = proxy.position(forX: day),
              let items = segmentsByDay[day] else {
            return nil
        }

        let totalTokens = items.reduce(0) { $0 + $1.tokens }
        guard let y = proxy.position(forY: totalTokens) else {
            return nil
        }

        let plotOrigin = geo[plotFrame].origin
        return CGPoint(x: plotOrigin.x + x, y: plotOrigin.y + y)
    }

    private func modelColor(for model: String) -> Color {
        guard let index = modelDomain.firstIndex(of: model) else {
            return Self.modelPalette[0]
        }
        return Self.modelPalette[index % Self.modelPalette.count]
    }

    private func tooltip(date: Date, items: [Segment]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(date, format: .dateTime.year().month().day())
                .font(.caption2.weight(.semibold))

            ScrollView(.vertical, showsIndicators: items.count > 5) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(items.sorted { $0.tokens > $1.tokens }) { item in
                        HStack(spacing: 10) {
                            Text(item.model)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(Formatters.compact(item.tokens))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxHeight: Self.tooltipRowsMaxHeight)
        }
        .padding(8)
        .frame(minWidth: 150, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tooltipBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.secondary.opacity(0.25))
        }
        // Flatten into one opaque layer so nothing shows through the tooltip.
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
    }
}

/// GitHub-style year picker laid out horizontally above the heatmap. No
/// explicit "Recent" entry: when no year is selected the heatmap shows the
/// rolling last-12-months view. Tapping the selected year clears it back to
/// that default.
private struct YearSelector: View {
    let years: [Int]
    @Binding var selectedYear: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(years, id: \.self) { year in
                chip(year)
            }
            Spacer(minLength: 0)
        }
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
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
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
