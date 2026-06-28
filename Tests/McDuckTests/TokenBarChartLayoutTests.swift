import Foundation
import Testing

@Suite("token bar chart layout")
struct TokenBarChartLayoutTests {
    @Test("token chart hides built in legend and renders an adaptive two column vertical model legend")
    func tokenChartUsesAdaptiveTwoColumnVerticalModelLegend() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let chart = try tokenBarChartSource(in: source)
        let legend = try modelLegendSource(in: chart)

        #expect(chart.contains(".chartLegend(.hidden)"))
        #expect(chart.contains("private var modelLegend: some View"))
        #expect(chart.contains("private static let legendColumnCount = 2"))
        #expect(chart.contains("private static let legendMaxRowCount = 3"))
        #expect(chart.contains("private static let legendRowHeight: CGFloat = 14"))
        #expect(chart.contains("private static let legendVerticalPadding: CGFloat = 4"))
        #expect(chart.contains("private var legendVisibleRowCount: Int"))
        #expect(chart.contains("(modelDomain.count + Self.legendColumnCount - 1) / Self.legendColumnCount"))
        #expect(chart.contains("min(Self.legendMaxRowCount, max(1, rowCount))"))
        #expect(legend.contains("ScrollView(.vertical"))
        #expect(legend.contains("LazyVGrid(columns: legendColumns"))
        #expect(legend.contains("showsIndicators: modelDomain.count > Self.legendColumnCount * Self.legendMaxRowCount"))
        #expect(legend.contains(".font(.caption2)"))
        #expect(legend.contains(".frame(height: Self.legendRowHeight * CGFloat(legendVisibleRowCount) + Self.legendVerticalPadding)"))
        #expect(!legend.contains("ScrollView(.horizontal"))
        #expect(!legend.contains("LazyHGrid("))
        #expect(!legend.contains("LazyVStack("))
        #expect(legend.contains(".truncationMode(.middle)"))
    }

    @Test("token chart keeps plot height independent from legend height")
    func tokenChartKeepsPlotHeightIndependentFromLegendHeight() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let loadedView = try loadedViewSource(in: source)
        let chart = try tokenBarChartSource(in: source)

        #expect(!loadedView.contains("TokenBarChart(days: store.filteredDays)\n                .frame(height: 120)"))
        #expect(chart.contains("chartBody\n                .frame(height: 120)"))
    }

    @Test("tooltip bounds per model rows so hover does not cover the chart")
    func tooltipBoundsModelRows() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let chart = try tokenBarChartSource(in: source)
        let tooltip = try tooltipSource(in: chart)

        #expect(tooltip.contains("ScrollView(.vertical"))
        #expect(tooltip.contains(".frame(maxHeight:"))
    }

    @Test("tooltip uses a compact base width but can grow to fit long model names")
    func tooltipUsesCompactBaseWidthAndIntrinsicGrowth() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let chart = try tokenBarChartSource(in: source)
        let tooltip = try tooltipSource(in: chart)

        #expect(chart.contains("private static let tooltipMinWidth: CGFloat = 90"))
        #expect(tooltip.contains(".frame(minWidth: Self.tooltipMinWidth, alignment: .leading)"))
        #expect(tooltip.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(!tooltip.contains(".frame(minWidth: 150"))
    }

    @Test("hover changes tooltip state only when the hovered day changes")
    func hoverUpdatesOnlyWhenHoveredDayChanges() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let chart = try tokenBarChartSource(in: source)
        let chartBody = try chartBodySource(in: chart)
        let updateHover = try updateHoverSource(in: chart)

        #expect(chartBody.contains("updateHover(at: location, proxy: proxy, geo: geo)"))
        #expect(!chartBody.contains("hoverLocation = hoveredDay == nil ? nil : location"))
        #expect(updateHover.contains("let nextDay = day(at: location, proxy: proxy, geo: geo)"))
        #expect(updateHover.contains("guard nextDay != hoveredDay else { return }"))
        #expect(updateHover.contains("hoveredDay = nextDay"))
    }

    @Test("tooltip accepts hover so long model lists can scroll")
    func tooltipAcceptsHoverForScrollableModelLists() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let chart = try tokenBarChartSource(in: source)
        let floatingTooltip = try floatingTooltipSource(in: chart)

        #expect(chart.contains("@State private var isTooltipHovered = false"))
        #expect(floatingTooltip.contains(".onContinuousHover"))
        #expect(floatingTooltip.contains("isTooltipHovered = true"))
        #expect(floatingTooltip.contains("clearHover()"))
        #expect(!floatingTooltip.contains(".allowsHitTesting(false)"))
    }

    @Test("tooltip anchors above the hovered bar without reserving layout space")
    func tooltipAnchorsAboveHoveredBarWithoutReservedLayoutSpace() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let chart = try tokenBarChartSource(in: source)
        let body = try bodySource(in: chart)
        let chartBody = try chartBodySource(in: chart)
        let floatingTooltip = try floatingTooltipSource(in: chart)

        #expect(chart.contains("@State private var tooltipAnchor: CGPoint?"))
        #expect(body.contains("chartBody\n                .frame(height: 120)\n                .overlay(alignment: .topLeading)"))
        #expect(!body.contains("tooltipArea"))
        #expect(!chart.contains("tooltipAreaHeight"))
        #expect(!chart.contains("tooltipFloatingOffset"))
        #expect(floatingTooltip.contains("tooltip(date: hoveredDay, items: items)"))
        #expect(floatingTooltip.contains("let tooltipAnchor"))
        #expect(floatingTooltip.contains(".alignmentGuide(.leading)"))
        #expect(floatingTooltip.contains("dimensions[HorizontalAlignment.center] - tooltipAnchor.x"))
        #expect(floatingTooltip.contains(".alignmentGuide(.top)"))
        #expect(chart.contains("private static let tooltipBarGap: CGFloat = 0"))
        #expect(floatingTooltip.contains("let tooltipBarGap = Self.tooltipBarGap"))
        #expect(floatingTooltip.contains("dimensions[VerticalAlignment.bottom] - tooltipAnchor.y + tooltipBarGap"))
        #expect(chart.contains("private func tooltipAnchor(for day: Date, proxy: ChartProxy, geo: GeometryProxy) -> CGPoint?"))
        #expect(chart.contains("proxy.position(forX: day)"))
        #expect(chart.contains("proxy.position(forY: totalTokens)"))
        #expect(!chartBody.contains("tooltip(date: hoveredDay, items: items)"))
    }

    @Test("tooltip above the chart does not track pointer location")
    func tooltipAboveChartDoesNotTrackPointerLocation() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let chart = try tokenBarChartSource(in: source)
        let updateHover = try updateHoverSource(in: chart)

        #expect(!chart.contains("hoverLocation"))
        #expect(!updateHover.contains("location ="))
        #expect(updateHover.contains("let nextAnchor = nextDay.flatMap"))
        #expect(updateHover.contains("tooltipAnchor = nextAnchor"))
    }

    private func mcDuckPopoverURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/McDuck/McDuckPopover.swift")
    }

    private func loadedViewSource(in source: String) throws -> Substring {
        let start = try #require(source.range(of: "private func loadedView() -> some View"))
        let end = try #require(source.range(of: "private var rangeControls: some View"))

        return source[start.lowerBound..<end.lowerBound]
    }

    private func tokenBarChartSource(in source: String) throws -> Substring {
        let start = try #require(source.range(of: "private struct TokenBarChart: View"))
        let end = try #require(source.range(of: "/// GitHub-style year picker"))

        return source[start.lowerBound..<end.lowerBound]
    }

    private func bodySource(in chart: Substring) throws -> Substring {
        let start = try #require(chart.range(of: "var body: some View"))
        let end = try #require(chart.range(of: "private var chartBody: some View"))

        return chart[start.lowerBound..<end.lowerBound]
    }

    private func modelLegendSource(in chart: Substring) throws -> Substring {
        let start = try #require(chart.range(of: "private var modelLegend: some View"))
        let end = try #require(chart.range(of: "private func day(at location:"))

        return chart[start.lowerBound..<end.lowerBound]
    }

    private func chartBodySource(in chart: Substring) throws -> Substring {
        let start = try #require(chart.range(of: "private var chartBody: some View"))
        let end = try #require(chart.range(of: "private var modelLegend: some View"))

        return chart[start.lowerBound..<end.lowerBound]
    }

    private func updateHoverSource(in chart: Substring) throws -> Substring {
        let start = try #require(chart.range(of: "private func updateHover(at location:"))
        let end = try #require(chart.range(of: "private func day(at location:"))

        return chart[start.lowerBound..<end.lowerBound]
    }

    private func floatingTooltipSource(in chart: Substring) throws -> Substring {
        let start = try #require(chart.range(of: "private var floatingTooltip: some View"))
        let end = try #require(chart.range(of: "private var chartBody: some View"))

        return chart[start.lowerBound..<end.lowerBound]
    }

    private func tooltipSource(in chart: Substring) throws -> Substring {
        let start = try #require(chart.range(of: "private func tooltip(date:"))

        return chart[start.lowerBound..<chart.endIndex]
    }
}
