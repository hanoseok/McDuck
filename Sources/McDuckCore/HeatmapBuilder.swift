import Foundation

public struct HeatmapCell: Identifiable, Equatable, Sendable {
    public var id: String { dateString }

    public let date: Date
    public let dateString: String
    public let day: UsageDay?
    public let intensity: Int
    /// True for padding cells that fall outside the requested range (rendered empty).
    public let isPlaceholder: Bool

    public init(date: Date, dateString: String, day: UsageDay?, intensity: Int, isPlaceholder: Bool = false) {
        self.date = date
        self.dateString = dateString
        self.day = day
        self.intensity = intensity
        self.isPlaceholder = isPlaceholder
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

    /// Builds week-aligned cells for an explicit date range. The grid is padded
    /// to whole weeks so columns line up by weekday; padding cells are marked as
    /// placeholders. Coloring intensity is relative to `days` (the full history),
    /// so it stays consistent across range/year selections.
    public func build(
        days: [UsageDay],
        rangeStart: Date,
        rangeEnd: Date,
        firstWeekday: Int = 1
    ) -> [HeatmapCell] {
        let start = calendar.startOfDay(for: rangeStart)
        let end = calendar.startOfDay(for: rangeEnd)
        guard start <= end else { return [] }

        let gridStart = startOfWeek(for: start, firstWeekday: firstWeekday)
        let gridEnd = endOfWeek(for: end, firstWeekday: firstWeekday)

        let daysByDate = Dictionary(uniqueKeysWithValues: days.map { ($0.dateString, $0) })
        let maxTokens = max(days.map(\.totalTokens).max() ?? 0, 0)

        var cells: [HeatmapCell] = []
        var date = gridStart
        while date <= gridEnd {
            let dateString = DateOnly.string(from: date)
            let inRange = date >= start && date <= end
            let day = inRange ? daysByDate[dateString] : nil
            cells.append(HeatmapCell(
                date: date,
                dateString: dateString,
                day: day,
                intensity: inRange ? Self.intensity(tokens: day?.totalTokens ?? 0, maxTokens: maxTokens) : 0,
                isPlaceholder: !inRange
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return cells
    }

    /// Rolling window ending today (default view): the last `months` months.
    public func recentMonths(
        days: [UsageDay],
        months: Int = 12,
        endingOn endDate: Date = Date(),
        firstWeekday: Int = 1
    ) -> [HeatmapCell] {
        let end = calendar.startOfDay(for: endDate)
        let monthsBack = calendar.date(byAdding: .month, value: -max(months, 1), to: end) ?? end
        let start = calendar.date(byAdding: .day, value: 1, to: monthsBack) ?? monthsBack
        return build(days: days, rangeStart: start, rangeEnd: end, firstWeekday: firstWeekday)
    }

    /// A single calendar year, clamped so it never extends past today.
    public func year(
        days: [UsageDay],
        year: Int,
        today: Date = Date(),
        firstWeekday: Int = 1
    ) -> [HeatmapCell] {
        let normalizedToday = calendar.startOfDay(for: today)
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? normalizedToday
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? normalizedToday
        let end = min(endOfYear, normalizedToday)
        return build(days: days, rangeStart: start, rangeEnd: end, firstWeekday: firstWeekday)
    }

    private func startOfWeek(for date: Date, firstWeekday: Int) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let diff = (weekday - firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -diff, to: date) ?? date
    }

    private func endOfWeek(for date: Date, firstWeekday: Int) -> Date {
        let weekStart = startOfWeek(for: date, firstWeekday: firstWeekday)
        return calendar.date(byAdding: .day, value: 6, to: weekStart) ?? date
    }

    private static func intensity(tokens: Int, maxTokens: Int) -> Int {
        guard tokens > 0, maxTokens > 0 else {
            return 0
        }

        let ratio = Double(tokens) / Double(maxTokens)
        return min(max(Int(ceil(ratio * 4)), 1), 4)
    }
}
