import McDuckCore
import SwiftUI

struct HeatmapGrid: View {
    let cells: [HeatmapCell]
    @Binding var selectedDateString: String?

    private var weeks: [[HeatmapCell]] {
        stride(from: 0, to: cells.count, by: 7).map { index in
            Array(cells[index..<min(index + 7, cells.count)])
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 4) {
                    ForEach(week) { cell in
                        cellButton(cell)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cellButton(_ cell: HeatmapCell) -> some View {
        let isSelected = selectedDateString == cell.dateString

        return Button {
            selectedDateString = cell.dateString
        } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color(for: cell.intensity))
                .frame(width: 13, height: 13)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(.primary, lineWidth: 1.2)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(helpText(for: cell))
        .accessibilityLabel(helpText(for: cell))
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
