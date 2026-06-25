import Foundation
import Testing

@Suite("token bar chart layout")
struct TokenBarChartLayoutTests {
    @Test("token chart hides built in legend and renders a bounded scrollable model legend")
    func tokenChartUsesScrollableModelLegend() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let chart = try tokenBarChartSource(in: source)
        let legend = try modelLegendSource(in: chart)

        #expect(chart.contains(".chartLegend(.hidden)"))
        #expect(chart.contains("private var modelLegend: some View"))
        #expect(legend.contains("ScrollView(.vertical"))
        #expect(legend.contains(".frame(maxHeight:"))
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

    private func modelLegendSource(in chart: Substring) throws -> Substring {
        let start = try #require(chart.range(of: "private var modelLegend: some View"))
        let end = try #require(chart.range(of: "private func day(at location:"))

        return chart[start.lowerBound..<end.lowerBound]
    }

    private func tooltipSource(in chart: Substring) throws -> Substring {
        let start = try #require(chart.range(of: "private func tooltip(date:"))

        return chart[start.lowerBound..<chart.endIndex]
    }
}
