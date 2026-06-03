import Foundation

public enum CcusageParseError: Error, Equatable, LocalizedError {
    case invalidDate(String)
    case missingDailyData
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDate(let value):
            "Invalid ccusage date: \(value)"
        case .missingDailyData:
            "No daily ccusage data was found."
        case .unreadable(let detail):
            "Could not read ccusage output. \(detail)"
        }
    }
}

public struct CcusageParser: Sendable {
    public init() {}

    public func parseDailyJSON(_ data: Data) throws -> UsageReport {
        let decoder = JSONDecoder()
        let payload: RawPayload
        do {
            payload = try decoder.decode(RawPayload.self, from: data)
        } catch {
            // Surface what ccusage actually returned so schema drift is diagnosable
            // instead of bubbling up an opaque "data couldn't be read" message.
            let snippet = String(decoding: data.prefix(240), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw CcusageParseError.unreadable(snippet.isEmpty ? "Output was empty." : "Output started with: \(snippet)")
        }

        let rawDays = payload.data ?? payload.daily ?? []
        guard !rawDays.isEmpty else {
            throw CcusageParseError.missingDailyData
        }

        // Skip entries without a usable date (e.g. aggregate rows) rather than
        // failing the whole report.
        let days = rawDays.compactMap { raw -> UsageDay? in
            // Newer ccusage names the day field `period`; older output uses `date`.
            guard let dateString = raw.date ?? raw.period, DateOnly.parse(dateString) != nil else {
                return nil
            }

            let breakdown = Self.breakdown(from: raw)

            return UsageDay(
                dateString: dateString,
                inputTokens: raw.inputTokens ?? 0,
                outputTokens: raw.outputTokens ?? 0,
                cacheCreationTokens: raw.cacheCreationTokens ?? 0,
                cacheReadTokens: raw.cacheReadTokens ?? 0,
                totalTokens: raw.totalTokens ?? 0,
                costUSD: raw.costUSD ?? raw.totalCost ?? 0,
                models: raw.models ?? raw.modelsUsed ?? breakdown.keys.sorted(),
                breakdown: breakdown
            )
        }
        .sorted { $0.date < $1.date }

        guard !days.isEmpty else {
            throw CcusageParseError.missingDailyData
        }

        let summary = Self.summary(from: payload.summary ?? payload.totals, fallbackDays: days)
        return UsageReport(days: days, summary: summary)
    }

    private static func breakdown(from raw: RawDay) -> [String: ModelUsage] {
        // ccusage emits per-model data either as a `breakdown` dictionary or,
        // with `--breakdown`, as a `modelBreakdowns` array keyed by `modelName`.
        if let dict = raw.breakdown {
            return dict.mapValues { usage in
                ModelUsage(
                    inputTokens: usage.inputTokens ?? 0,
                    outputTokens: usage.outputTokens ?? 0,
                    cacheCreationTokens: usage.cacheCreationTokens ?? 0,
                    cacheReadTokens: usage.cacheReadTokens ?? 0,
                    totalTokens: usage.totalTokens ?? 0,
                    costUSD: usage.costUSD ?? usage.cost ?? usage.totalCost ?? 0
                )
            }
        }

        if let list = raw.modelBreakdowns {
            var result: [String: ModelUsage] = [:]
            for item in list {
                guard let name = item.modelName else { continue }
                result[name] = ModelUsage(
                    inputTokens: item.inputTokens ?? 0,
                    outputTokens: item.outputTokens ?? 0,
                    cacheCreationTokens: item.cacheCreationTokens ?? 0,
                    cacheReadTokens: item.cacheReadTokens ?? 0,
                    totalTokens: item.totalTokens ?? 0,
                    costUSD: item.costUSD ?? item.cost ?? item.totalCost ?? 0
                )
            }
            return result
        }

        return [:]
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
    var date: String?
    var period: String?
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
    var modelBreakdowns: [RawModelBreakdown]?
}

private struct RawUsage: Decodable {
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheCreationTokens: Int?
    var cacheReadTokens: Int?
    var totalTokens: Int?
    var costUSD: Double?
    var cost: Double?
    var totalCost: Double?
}

private struct RawModelBreakdown: Decodable {
    var modelName: String?
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheCreationTokens: Int?
    var cacheReadTokens: Int?
    var totalTokens: Int?
    var costUSD: Double?
    var cost: Double?
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
