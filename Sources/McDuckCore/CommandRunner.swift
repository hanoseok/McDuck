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
        let output = PipeOutputCollector(stdout: stdoutPipe, stderr: stderrPipe)

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
        stdoutPipe.fileHandleForWriting.closeFile()
        stderrPipe.fileHandleForWriting.closeFile()

        output.start()

        let timeoutAt = Date().addingTimeInterval(request.timeout)
        while process.isRunning, Date() < timeoutAt {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            let captured = output.finish()
            return CommandResult(
                exitCode: -9,
                stdout: String(data: captured.stdout, encoding: .utf8) ?? "",
                stderr: "Command timed out after \(Int(request.timeout)) seconds."
            )
        }

        process.waitUntilExit()
        let captured = output.finish()
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: captured.stdout, encoding: .utf8) ?? "",
            stderr: String(data: captured.stderr, encoding: .utf8) ?? ""
        )
    }
}

private final class PipeOutputCollector: @unchecked Sendable {
    private let stdout: FileHandle
    private let stderr: FileHandle
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()

    init(stdout: Pipe, stderr: Pipe) {
        self.stdout = stdout.fileHandleForReading
        self.stderr = stderr.fileHandleForReading
    }

    func start() {
        read(stdout, stream: .stdout)
        read(stderr, stream: .stderr)
    }

    func finish() -> (stdout: Data, stderr: Data) {
        group.wait()
        lock.lock()
        defer { lock.unlock() }
        return (stdoutData, stderrData)
    }

    private func read(_ handle: FileHandle, stream: PipeStream) {
        group.enter()
        DispatchQueue.global(qos: .utility).async { [self] in
            defer { group.leave() }

            while true {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    return
                }

                lock.lock()
                switch stream {
                case .stdout:
                    stdoutData.append(chunk)
                case .stderr:
                    stderrData.append(chunk)
                }
                lock.unlock()
            }
        }
    }

    private enum PipeStream: Sendable {
        case stdout
        case stderr
    }
}
