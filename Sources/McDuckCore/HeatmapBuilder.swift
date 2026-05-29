import Foundation

public struct HeatmapCell: Identifiable, Equatable, Sendable {
    public var id: String { dateString }

    public let date: Date
    public let dateString: String
    public let day: UsageDay?
    public let intensity: Int

    public init(date: Date, dateString: String, day: UsageDay?, intensity: Int) {
        self.date = date
        self.dateString = dateString
        self.day = day
        self.intensity = intensity
    }
}

public struct HeatmapBuilder: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    public func build(days: [UsageDay], endingOn endDate: Date = Date(), weeks: Int = 12) -> [HeatmapCell] {
        let normalizedEnd = calendar.startOfDay(for: endDate)
        let count = max(weeks, 1) * 7
        let start = calendar.date(byAdding: .day, value: -(count - 1), to: normalizedEnd) ?? normalizedEnd
        let daysByDate = Dictionary(uniqueKeysWithValues: days.map { ($0.dateString, $0) })
        let maxTokens = max(days.map(\.totalTokens).max() ?? 0, 0)

        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            let dateString = DateOnly.string(from: date)
            let day = daysByDate[dateString]
            return HeatmapCell(
                date: date,
                dateString: dateString,
                day: day,
                intensity: Self.intensity(tokens: day?.totalTokens ?? 0, maxTokens: maxTokens)
            )
        }
    }

    private static func intensity(tokens: Int, maxTokens: Int) -> Int {
        guard tokens > 0, maxTokens > 0 else {
            return 0
        }

        let ratio = Double(tokens) / Double(maxTokens)
        return min(max(Int(ceil(ratio * 4)), 1), 4)
    }
}
