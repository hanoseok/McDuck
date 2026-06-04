import Foundation
import Testing
@testable import McDuckCore

/// Additional `DependencyManager` coverage: message cleanup, version trimming,
/// and the bootstrap path (including the missing-Bun short-circuit).
@Suite("dependency manager edge cases")
struct DependencyManagerAdditionalTests {
    @Test("ready status trims surrounding whitespace from the version string")
    func readyTrimsVersion() async {
        let manager = DependencyManager(
            runner: FixedRunner(result: CommandResult(exitCode: 0, stdout: "  19.1.0  \n", stderr: "")),
            bunLocator: StaticBunLocator(path: "/bun")
        )

        #expect(await manager.check() == .ready(bunPath: "/bun", ccusageVersion: "19.1.0"))
    }

    @Test("unavailable status uses stdout when stderr is empty")
    func unavailableUsesStdoutWhenStderrEmpty() async {
        let manager = DependencyManager(
            runner: FixedRunner(result: CommandResult(exitCode: 1, stdout: "stdout detail", stderr: "")),
            bunLocator: StaticBunLocator(path: "/bun")
        )

        #expect(await manager.check() == .ccusageUnavailable(bunPath: "/bun", message: "stdout detail"))
    }

    @Test("unavailable status falls back to a default message when both streams are empty")
    func unavailableDefaultMessage() async {
        let manager = DependencyManager(
            runner: FixedRunner(result: CommandResult(exitCode: 1, stdout: "   ", stderr: "")),
            bunLocator: StaticBunLocator(path: "/bun")
        )

        #expect(await manager.check() == .ccusageUnavailable(bunPath: "/bun", message: "ccusage could not be started."))
    }

    @Test("bootstrapCcusage short-circuits with exit 127 when Bun is missing")
    func bootstrapMissingBun() async {
        let manager = DependencyManager(
            runner: FixedRunner(result: CommandResult(exitCode: 0, stdout: "should not be used", stderr: "")),
            bunLocator: StaticBunLocator(path: nil)
        )

        let result = await manager.bootstrapCcusage()

        #expect(result.exitCode == 127)
        #expect(result.stderr == "Bun is not installed.")
    }

    @Test("bootstrapCcusage passes the runner result through when Bun is present")
    func bootstrapPassesThroughResult() async {
        let manager = DependencyManager(
            runner: FixedRunner(result: CommandResult(exitCode: 0, stdout: "20.0.0", stderr: "")),
            bunLocator: StaticBunLocator(path: "/bun")
        )

        let result = await manager.bootstrapCcusage()

        #expect(result.exitCode == 0)
        #expect(result.stdout == "20.0.0")
    }
}

private struct FixedRunner: CommandRunner {
    let result: CommandResult

    func run(_ request: CommandRequest) async -> CommandResult {
        result
    }
}
