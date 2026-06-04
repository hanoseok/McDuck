import McDuckCore
import SwiftUI

struct HeatmapGrid: View {
    let cells: [HeatmapCell]
    @Binding var selectedDateString: String?

    private let cellSize: CGFloat = 6
    private let spacing: CGFloat = 1

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private var weeks: [[HeatmapCell]] {
        stride(from: 0, to: cells.count, by: 7).map { index in
            Array(cells[index..<min(index + 7, cells.count)])
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                monthLabels
                grid
            }
            .padding(.trailing, 2)
        }
        .defaultScrollAnchor(.trailing)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthLabels: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, _ in
                Text(monthLabel(forColumn: index))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(width: cellSize, alignment: .leading)
            }
        }
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: spacing) {
                    ForEach(week) { cell in
                        cellView(cell)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: HeatmapCell) -> some View {
        if cell.isPlaceholder {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.clear)
                .frame(width: cellSize, height: cellSize)
        } else {
            let isSelected = selectedDateString == cell.dateString
            Button {
                selectedDateString = cell.dateString
            } label: {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(color(for: cell.intensity))
                    .frame(width: cellSize, height: cellSize)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .stroke(.primary, lineWidth: 1)
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(helpText(for: cell))
            .accessibilityLabel(helpText(for: cell))
        }
    }

    private func monthLabel(forColumn index: Int) -> String {
        guard let top = weeks[index].first else {
            return ""
        }

        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: top.date)

        if index == 0 {
            // Only label the first column if it begins near the start of a month,
            // otherwise the label would crowd the next month's label.
            return calendar.component(.day, from: top.date) <= 7 ? Self.shortMonth(top.date) : ""
        }

        guard let previousTop = weeks[index - 1].first else {
            return ""
        }

        let previousMonth = calendar.component(.month, from: previousTop.date)
        return month != previousMonth ? Self.shortMonth(top.date) : ""
    }

    private static func shortMonth(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    private func color(for intensity: Int) -> Color {
        switch intensity {
        case 1:
            Color.green.opacity(0.35)
        case 2:
            Color.green.opacity(0.55)
        case 3:
            Color.green.opacity(0.75)
        case 4:
            Color.green
        default:
            Color.secondary.opacity(0.16)
        }
    }

    private func helpText(for cell: HeatmapCell) -> String {
        guard let day = cell.day else {
            return "\(cell.dateString): no usage"
        }

        return "\(cell.dateString): \(Formatters.compact(day.totalTokens)) tokens, \(Formatters.currency(day.costUSD))"
    }
}
