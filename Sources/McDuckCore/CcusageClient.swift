import Foundation

public enum CcusageClientError: Error, Equatable, LocalizedError {
    case missingBun
    case ccusageUnavailable(String)
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingBun:
            "Bun is not installed."
        case .ccusageUnavailable(let message):
            message
        case .commandFailed(let message):
            message
        }
    }
}

public struct CcusageClient: Sendable {
    private let runner: any CommandRunner
    private let dependencyManager: DependencyManager
    private let parser: CcusageParser

    public init(
        runner: any CommandRunner = ProcessCommandRunner(),
        bunLocator: any BunLocating = BunLocator(),
        parser: CcusageParser = CcusageParser()
    ) {
        self.runner = runner
        self.dependencyManager = DependencyManager(runner: runner, bunLocator: bunLocator)
        self.parser = parser
    }

    public func checkDependencies() async -> DependencyStatus {
        await dependencyManager.check()
    }

    public func bootstrapCcusage() async -> CommandResult {
        await dependencyManager.bootstrapCcusage()
    }

    public func installBun() async -> CommandResult {
        await dependencyManager.installBun()
    }

    public func loadDailyReport() async throws -> UsageReport {
        let status = await dependencyManager.check()
        switch status {
        case .missingBun:
            throw CcusageClientError.missingBun
        case .ccusageUnavailable(_, let message):
            throw CcusageClientError.ccusageUnavailable(message)
        case .ready(let bunPath, _):
            let result = await runner.run(CommandRequest(
                executable: bunPath,
                arguments: ["x", "ccusage", "daily", "--json", "--breakdown"],
                environment: ["PATH": BunLocator.augmentedPATH(bunPath: bunPath)],
                timeout: 90
            ))

            guard result.exitCode == 0 else {
                let message = result.stderr.isEmpty ? result.stdout : result.stderr
                throw CcusageClientError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return try parser.parseDailyJSON(Data(result.stdout.utf8))
        }
    }

    /// Best-effort per-day active duration (seconds) from `ccusage blocks`.
    /// Supplementary data: any failure returns an empty map instead of throwing
    /// so it never disrupts the main usage report.
    public func loadDailyActivity() async -> [String: TimeInterval] {
        guard case .ready(let bunPath, _) = await dependencyManager.check() else {
            return [:]
        }

        let result = await runner.run(CommandRequest(
            executable: bunPath,
            arguments: ["x", "ccusage", "blocks", "--json"],
            environment: ["PATH": BunLocator.augmentedPATH(bunPath: bunPath)],
            timeout: 90
        ))

        guard result.exitCode == 0 else {
            return [:]
        }

        return (try? parser.parseBlocksJSON(Data(result.stdout.utf8))) ?? [:]
    }
}
