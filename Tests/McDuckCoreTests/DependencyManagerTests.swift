import Foundation
import Testing
@testable import McDuckCore

@Suite("dependency manager")
struct DependencyManagerTests {
    @Test("reports missing Bun when locator cannot find executable")
    func reportsMissingBun() async {
        let manager = DependencyManager(
            runner: FakeRunner(results: []),
            bunLocator: StaticBunLocator(path: nil)
        )

        let status = await manager.check()

        #expect(status == .missingBun)
    }

    @Test("reports ready when bunx can start ccusage")
    func reportsReadyWhenCcusageRuns() async {
        let manager = DependencyManager(
            runner: FakeRunner(results: [
                CommandResult(exitCode: 0, stdout: "20.0.4\n", stderr: "")
            ]),
            bunLocator: StaticBunLocator(path: "/Users/test/.bun/bin/bun")
        )

        let status = await manager.check()

        #expect(status == .ready(bunPath: "/Users/test/.bun/bin/bun", ccusageVersion: "20.0.4"))
    }

    @Test("reports ccusage unavailable when bunx command fails")
    func reportsCcusageUnavailable() async {
        let manager = DependencyManager(
            runner: FakeRunner(results: [
                CommandResult(exitCode: 1, stdout: "", stderr: "package failed")
            ]),
            bunLocator: StaticBunLocator(path: "/Users/test/.bun/bin/bun")
        )

        let status = await manager.check()

        #expect(status == .ccusageUnavailable(bunPath: "/Users/test/.bun/bin/bun", message: "package failed"))
    }
}

private struct FakeRunner: CommandRunner {
    var results: [CommandResult]

    func run(_ request: CommandRequest) async -> CommandResult {
        results.first ?? CommandResult(exitCode: 127, stdout: "", stderr: "missing fake result")
    }
}
