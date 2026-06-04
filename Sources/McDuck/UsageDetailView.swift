import McDuckCore
import SwiftUI

struct UsageDetailView: View {
    let day: UsageDay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.dateString)
                        .font(.headline)
                    Text("\(Formatters.compact(day.totalTokens)) tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(Formatters.currency(day.costUSD))
                    .font(.title3.weight(.semibold))
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    metric("Input", day.inputTokens)
                    metric("Output", day.outputTokens)
                }
                GridRow {
                    metric("Cache write", day.cacheCreationTokens)
                    metric("Cache read", day.cacheReadTokens)
                }
            }

            if !modelRows.isEmpty {
                Divider()

                VStack(spacing: 7) {
                    HStack(spacing: 8) {
                        Text("Model")
                        Spacer()
                        Text("Tokens")
                            .frame(width: 64, alignment: .trailing)
                        Text("Cost")
                            .frame(width: 64, alignment: .trailing)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    ForEach(modelRows, id: \.name) { row in
                        HStack(spacing: 8) {
                            Text(row.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(Formatters.compact(row.tokens))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .trailing)
                            Text(Formatters.currency(row.cost))
                                .font(.caption.weight(.medium))
                                .frame(width: 64, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(12)
        .mcDuckGlass(cornerRadius: 14)
    }

    private var modelRows: [(name: String, tokens: Int, cost: Double)] {
        if !day.breakdown.isEmpty {
            return day.breakdown
                .map { (name: $0.key, tokens: $0.value.totalTokens, cost: $0.value.costUSD) }
                .sorted { $0.tokens > $1.tokens }
        }

        return day.models.map { (name: $0, tokens: 0, cost: 0) }
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Formatters.compact(value))
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum Formatters {
    static func compact(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName))
    }

    static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}
