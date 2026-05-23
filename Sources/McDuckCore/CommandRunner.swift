import Foundation

public struct CommandRequest: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String: String]
    public let timeout: TimeInterval

    public init(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval = 30
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.timeout = timeout
    }
}

public struct CommandResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol CommandRunner: Sendable {
    func run(_ request: CommandRequest) async -> CommandResult
}

public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func run(_ request: CommandRequest) async -> CommandResult {
        await Task.detached(priority: .utility) {
            Self.runBlocking(request)
        }.value
    }

    private static func runBlocking(_ request: CommandRequest) -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: request.executable)
        process.arguments = request.arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var environment = ProcessInfo.processInfo.environment
        request.environment.forEach { key, value in
            environment[key] = value
        }
        process.environment = environment

        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }

        let timeoutAt = Date().addingTimeInterval(request.timeout)
        while process.isRunning, Date() < timeoutAt {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            return CommandResult(
                exitCode: -9,
                stdout: String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
                stderr: "Command timed out after \(Int(request.timeout)) seconds."
            )
        }

        process.waitUntilExit()
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }
}
