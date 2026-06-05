import Foundation
import Testing
@testable import McDuckCore

/// Exercises `CcusageClient` end to end with a request-aware fake runner that
/// returns different results for the dependency check (`--version`), the daily
/// report, and the `blocks` activity query.
@Suite("ccusage client")
struct CcusageClientTests {
    private static let dailyJSON = """
    {
      "daily": [
        { "date": "2026-05-20", "inputTokens": 10, "outputTokens": 20, "totalTokens": 30, "totalCost": 1.5 }
      ]
    }
    """

    private static let blocksJSON = """
    {
      "blocks": [
        {
          "startTime": "2026-05-20T12:00:00.000Z",
          "actualEndTime": "2026-05-20T13:00:00.000Z"
        }
      ]
    }
    """

    private func client(
        bunPath: String? = "/bun",
        handler: @escaping @Sendable (CommandRequest) -> CommandResult
    ) -> CcusageClient {
        CcusageClient(
            runner: ScriptedRunner(handle: handler),
            bunLocator: StaticBunLocator(path: bunPath)
        )
    }

    // MARK: - loadDailyReport

    @Test("throws missingBun when Bun cannot be located")
    func loadReportMissingBun() async {
        let client = client(bunPath: nil) { _ in
            CommandResult(exitCode: 0, stdout: "", stderr: "")
        }

        await #expect(throws: CcusageClientError.missingBun) {
            _ = try await client.loadDailyReport()
        }
    }

    @Test("throws ccusageUnavailable when the dependency check fails")
    func loadReportCcusageUnavailable() async {
        let client = client { request in
            if request.arguments.contains("--version") {
                return CommandResult(exitCode: 1, stdout: "", stderr: "boom")
            }
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }

        await #expect(throws: CcusageClientError.ccusageUnavailable("boom")) {
            _ = try await client.loadDailyReport()
        }
    }

    @Test("returns a parsed report when bunx and ccusage succeed")
    func loadReportSuccess() async throws {
        let client = client { request in
            if request.arguments.contains("--version") {
                return CommandResult(exitCode: 0, stdout: "20.0.0", stderr: "")
            }
            return CommandResult(exitCode: 0, stdout: Self.dailyJSON, stderr: "")
        }

        let report = try await client.loadDailyReport()

        #expect(report.days.map(\.dateString) == ["2026-05-20"])
        #expect(report.days[0].totalTokens == 30)
    }

    @Test("throws commandFailed with stderr when the daily command exits non-zero")
    func loadReportCommandFailedStderr() async {
        let client = client { request in
            if request.arguments.contains("--version") {
                return CommandResult(exitCode: 0, stdout: "20.0.0", stderr: "")
            }
            return CommandResult(exitCode: 1, stdout: "", stderr: "daily failed")
        }

        await #expect(throws: CcusageClientError.commandFailed("daily failed")) {
            _ = try await client.loadDailyReport()
        }
    }

    @Test("commandFailed uses stdout when stderr is empty")
    func loadReportCommandFailedStdout() async {
        let client = client { request in
            if request.arguments.contains("--version") {
                return CommandResult(exitCode: 0, stdout: "20.0.0", stderr: "")
            }
            return CommandResult(exitCode: 2, stdout: "stdout failure", stderr: "")
        }

        await #expect(throws: CcusageClientError.commandFailed("stdout failure")) {
            _ = try await client.loadDailyReport()
        }
    }

    // MARK: - loadDailyActivity (best-effort, never throws)

    @Test("activity is empty when Bun is missing")
    func activityMissingBun() async {
        let client = client(bunPath: nil) { _ in
            CommandResult(exitCode: 0, stdout: "", stderr: "")
        }

        #expect(await client.loadDailyActivity().isEmpty)
    }

    @Test("activity is parsed from a successful blocks query")
    func activitySuccess() async {
        let client = client { request in
            if request.arguments.contains("--version") {
                return CommandResult(exitCode: 0, stdout: "20.0.0", stderr: "")
            }
            return CommandResult(exitCode: 0, stdout: Self.blocksJSON, stderr: "")
        }

        let activity = await client.loadDailyActivity()

        #expect(activity.values.reduce(0, +) == 3600)
    }

    @Test("activity is empty when the blocks command fails")
    func activityCommandFails() async {
        let client = client { request in
            if request.arguments.contains("--version") {
                return CommandResult(exitCode: 0, stdout: "20.0.0", stderr: "")
            }
            return CommandResult(exitCode: 1, stdout: "", stderr: "blocks failed")
        }

        #expect(await client.loadDailyActivity().isEmpty)
    }

    @Test("activity is empty when the blocks output cannot be parsed")
    func activityUnparseable() async {
        let client = client { request in
            if request.arguments.contains("--version") {
                return CommandResult(exitCode: 0, stdout: "20.0.0", stderr: "")
            }
            return CommandResult(exitCode: 0, stdout: "not json", stderr: "")
        }

        #expect(await client.loadDailyActivity().isEmpty)
    }
}

/// A `CommandRunner` that delegates to a closure, letting each test decide what
/// to return based on the request's arguments.
private struct ScriptedRunner: CommandRunner {
    let handle: @Sendable (CommandRequest) -> CommandResult

    func run(_ request: CommandRequest) async -> CommandResult {
        handle(request)
    }
}
