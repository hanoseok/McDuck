import Foundation

public struct ModelUsage: Equatable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let totalTokens: Int
    public let costUSD: Double

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        totalTokens: Int,
        costUSD: Double
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.totalTokens = totalTokens
        self.costUSD = costUSD
    }
}

public struct UsageDay: Identifiable, Equatable, Sendable {
    public var id: String { dateString }

    public let date: Date
    public let dateString: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let totalTokens: Int
    public let costUSD: Double
    public let models: [String]
    public let breakdown: [String: ModelUsage]

    public init(
        dateString: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        totalTokens: Int,
        costUSD: Double,
        models: [String],
        breakdown: [String: ModelUsage]
    ) {
        self.dateString = dateString
        self.date = DateOnly.parse(dateString) ?? .distantPast
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.totalTokens = totalTokens
        self.costUSD = costUSD
        self.models = models
        self.breakdown = breakdown
    }
}

public struct UsageSummary: Equatable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let totalTokens: Int
    public let totalCostUSD: Double

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        totalTokens: Int,
        totalCostUSD: Double
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.totalTokens = totalTokens
        self.totalCostUSD = totalCostUSD
    }
}

public struct UsageReport: Equatable, Sendable {
    public let days: [UsageDay]
    public let summary: UsageSummary

    public init(days: [UsageDay], summary: UsageSummary) {
        self.days = days
        self.summary = summary
    }
}

enum DateOnly {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        formatter.date(from: value)
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
