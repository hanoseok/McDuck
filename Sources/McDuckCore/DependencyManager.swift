import Foundation

public enum DependencyStatus: Equatable, Sendable {
    case ready(bunPath: String, ccusageVersion: String)
    case missingBun
    case ccusageUnavailable(bunPath: String, message: String)
}

public struct DependencyManager: Sendable {
    private let runner: any CommandRunner
    private let bunLocator: any BunLocating

    public init(runner: any CommandRunner, bunLocator: any BunLocating = BunLocator()) {
        self.runner = runner
        self.bunLocator = bunLocator
    }

    public func check() async -> DependencyStatus {
        guard let bunPath = bunLocator.findBun() else {
            return .missingBun
        }

        let result = await runner.run(CommandRequest(
            executable: bunPath,
            arguments: ["x", "ccusage", "--version"],
            timeout: 60
        ))

        if result.exitCode == 0 {
            return .ready(bunPath: bunPath, ccusageVersion: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return .ccusageUnavailable(
            bunPath: bunPath,
            message: Self.cleanMessage(stdout: result.stdout, stderr: result.stderr)
        )
    }

    public func bootstrapCcusage() async -> CommandResult {
        guard let bunPath = bunLocator.findBun() else {
            return CommandResult(exitCode: 127, stdout: "", stderr: "Bun is not installed.")
        }

        return await runner.run(CommandRequest(
            executable: bunPath,
            arguments: ["x", "ccusage", "--version"],
            timeout: 120
        ))
    }

    public func installBun() async -> CommandResult {
        await runner.run(CommandRequest(
            executable: "/bin/zsh",
            arguments: ["-lc", "curl -fsSL https://bun.sh/install | bash"],
            timeout: 300
        ))
    }

    private static func cleanMessage(stdout: String, stderr: String) -> String {
        let message = stderr.isEmpty ? stdout : stderr
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "ccusage could not be started." : trimmed
    }
}
