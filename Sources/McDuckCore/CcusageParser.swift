import Foundation

public enum CcusageParseError: Error, Equatable, LocalizedError {
    case invalidDate(String)
    case missingDailyData

    public var errorDescription: String? {
        switch self {
        case .invalidDate(let value):
            "Invalid ccusage date: \(value)"
        case .missingDailyData:
            "No daily ccusage data was found."
        }
    }
}

public struct CcusageParser: Sendable {
    public init() {}

    public func parseDailyJSON(_ data: Data) throws -> UsageReport {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(RawPayload.self, from: data)
        let rawDays = payload.data ?? payload.daily ?? []

        guard !rawDays.isEmpty else {
            throw CcusageParseError.missingDailyData
        }

        let days = try rawDays.map { raw -> UsageDay in
            guard DateOnly.parse(raw.date) != nil else {
                throw CcusageParseError.invalidDate(raw.date)
            }

            let breakdown = raw.breakdown?.mapValues { usage in
                ModelUsage(
                    inputTokens: usage.inputTokens ?? 0,
                    outputTokens: usage.outputTokens ?? 0,
                    cacheCreationTokens: usage.cacheCreationTokens ?? 0,
                    cacheReadTokens: usage.cacheReadTokens ?? 0,
                    totalTokens: usage.totalTokens ?? 0,
                    costUSD: usage.costUSD ?? usage.totalCost ?? 0
                )
            } ?? [:]

            return UsageDay(
                dateString: raw.date,
                inputTokens: raw.inputTokens ?? 0,
                outputTokens: raw.outputTokens ?? 0,
                cacheCreationTokens: raw.cacheCreationTokens ?? 0,
                cacheReadTokens: raw.cacheReadTokens ?? 0,
                totalTokens: raw.totalTokens ?? 0,
                costUSD: raw.costUSD ?? raw.totalCost ?? 0,
                models: raw.models ?? raw.modelsUsed ?? Array(breakdown.keys).sorted(),
                breakdown: breakdown
            )
        }
        .sorted { $0.date < $1.date }

        let summary = Self.summary(from: payload.summary ?? payload.totals, fallbackDays: days)
        return UsageReport(days: days, summary: summary)
    }

    private static func summary(from raw: RawSummary?, fallbackDays days: [UsageDay]) -> UsageSummary {
        UsageSummary(
            inputTokens: raw?.totalInputTokens ?? raw?.inputTokens ?? days.reduce(0) { $0 + $1.inputTokens },
            outputTokens: raw?.totalOutputTokens ?? raw?.outputTokens ?? days.reduce(0) { $0 + $1.outputTokens },
            cacheCreationTokens: raw?.totalCacheCreationTokens ?? raw?.cacheCreationTokens ?? days.reduce(0) { $0 + $1.cacheCreationTokens },
            cacheReadTokens: raw?.totalCacheReadTokens ?? raw?.cacheReadTokens ?? days.reduce(0) { $0 + $1.cacheReadTokens },
            totalTokens: raw?.totalTokens ?? days.reduce(0) { $0 + $1.totalTokens },
            totalCostUSD: raw?.totalCostUSD ?? raw?.totalCost ?? raw?.costUSD ?? days.reduce(0) { $0 + $1.costUSD }
        )
    }
}

private struct RawPayload: Decodable {
    var type: String?
    var data: [RawDay]?
    var daily: [RawDay]?
    var summary: RawSummary?
    var totals: RawSummary?
}

private struct RawDay: Decodable {
    var date: String
    var models: [String]?
    var modelsUsed: [String]?
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheCreationTokens: Int?
    var cacheReadTokens: Int?
    var totalTokens: Int?
    var costUSD: Double?
    var totalCost: Double?
    var breakdown: [String: RawUsage]?
}

private struct RawUsage: Decodable {
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheCreationTokens: Int?
    var cacheReadTokens: Int?
    var totalTokens: Int?
    var costUSD: Double?
    var totalCost: Double?
}

private struct RawSummary: Decodable {
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheCreationTokens: Int?
    var cacheReadTokens: Int?
    var totalInputTokens: Int?
    var totalOutputTokens: Int?
    var totalCacheCreationTokens: Int?
    var totalCacheReadTokens: Int?
    var totalTokens: Int?
    var costUSD: Double?
    var totalCost: Double?
    var totalCostUSD: Double?
}
