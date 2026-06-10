import Foundation
import Testing
@testable import McDuckCore

/// Integration coverage for `ProcessCommandRunner`. These shell out to standard
/// macOS binaries (`/bin/echo`, `/bin/sh`, `/bin/sleep`), so they run on the
/// macOS CI runner rather than the Linux dev container.
@Suite("process command runner")
struct CommandRunnerTests {
    @Test("captures stdout and a zero exit code on success")
    func capturesStdout() async {
        let result = await ProcessCommandRunner().run(
            CommandRequest(executable: "/bin/echo", arguments: ["hello world"])
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello world")
        #expect(result.stderr.isEmpty)
    }

    @Test("propagates a non-zero exit code")
    func propagatesNonZeroExit() async {
        let result = await ProcessCommandRunner().run(
            CommandRequest(executable: "/bin/sh", arguments: ["-c", "exit 3"])
        )

        #expect(result.exitCode == 3)
    }

    @Test("merges the request environment into the subprocess")
    func mergesEnvironment() async {
        let result = await ProcessCommandRunner().run(
            CommandRequest(
                executable: "/bin/sh",
                arguments: ["-c", "printf %s \"$MCDUCK_TEST_VAR\""],
                environment: ["MCDUCK_TEST_VAR": "injected"]
            )
        )

        #expect(result.stdout == "injected")
    }

    @Test("returns exit code 127 when the executable cannot be launched")
    func missingExecutableReturns127() async {
        let result = await ProcessCommandRunner().run(
            CommandRequest(executable: "/nonexistent/mcduck-binary", arguments: [])
        )

        #expect(result.exitCode == 127)
        #expect(!result.stderr.isEmpty)
    }

    @Test("terminates and reports a timeout for a long-running command")
    func timesOutLongCommand() async {
        let result = await ProcessCommandRunner().run(
            CommandRequest(executable: "/bin/sleep", arguments: ["5"], timeout: 0.3)
        )

        #expect(result.exitCode == -9)
        #expect(result.stderr.lowercased().contains("timed out"))
    }

    @Test("drains large stdout while the process is still running")
    func drainsLargeStdoutWhileRunning() async {
        let result = await ProcessCommandRunner().run(
            CommandRequest(
                executable: "/bin/sh",
                arguments: ["-c", "/usr/bin/yes x | /usr/bin/head -c 200000"],
                timeout: 2
            )
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.utf8.count == 200_000)
    }

    @Test("CommandRequest applies its documented defaults")
    func commandRequestDefaults() {
        let request = CommandRequest(executable: "/bin/echo", arguments: ["x"])

        #expect(request.environment.isEmpty)
        #expect(request.timeout == 30)
    }
}
