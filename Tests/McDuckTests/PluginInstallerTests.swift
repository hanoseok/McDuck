import Foundation
import Testing
import McDuckCore
@testable import McDuck

// MARK: - Fakes

/// CommandRunner that answers by inspecting the arguments, so the installer's
/// two calls (marketplace add, install) can be scripted independently.
private struct ScriptedRunner: CommandRunner {
    var addExit: Int32 = 0
    var installExit: Int32 = 0

    func run(_ request: CommandRequest) async -> CommandResult {
        if request.arguments.contains("add") {
            return CommandResult(exitCode: addExit, stdout: "", stderr: addExit == 0 ? "" : "add failed")
        }
        if request.arguments.contains("install") {
            return CommandResult(exitCode: installExit, stdout: "", stderr: installExit == 0 ? "" : "install failed")
        }
        return CommandResult(exitCode: 127, stdout: "", stderr: "unexpected")
    }
}

private final class InMemorySettingsIO: SettingsFileIO, @unchecked Sendable {
    var stored: Data?
    var writeError: Error?
    private(set) var wroteCount = 0

    init(stored: Data? = nil) { self.stored = stored }

    func read(_ url: URL) -> Data? { stored }

    func write(_ data: Data, to url: URL) throws {
        if let writeError { throw writeError }
        stored = data
        wroteCount += 1
    }
}

private enum WriteFailure: Error { case denied }

private func installer(
    claude: String? = nil,
    marketplacePath: String? = "/Applications/McDuck.app/Contents/Resources/ClaudePlugin",
    runner: ScriptedRunner = ScriptedRunner(),
    io: InMemorySettingsIO = InMemorySettingsIO()
) -> PluginInstaller {
    PluginInstaller(
        runner: runner,
        claudeExecutable: claude,
        marketplacePath: marketplacePath,
        settingsURL: URL(fileURLWithPath: "/tmp/McDuckTests/settings.json"),
        fileIO: io
    )
}

private func parse(_ data: Data?) throws -> [String: Any] {
    let data = try #require(data)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

// MARK: - settings.json merge

@Suite("claude plugin settings merge")
struct ClaudePluginSettingsTests {
    @Test("a fresh file gets the directory marketplace and enabled plugin")
    func freshFile() throws {
        let obj = try parse(ClaudePluginSettings.merged(intoExisting: nil, marketplacePath: "/abs/ClaudePlugin"))

        let market = try #require((obj["extraKnownMarketplaces"] as? [String: Any])?["mcduck"] as? [String: Any])
        let source = try #require(market["source"] as? [String: Any])
        #expect(source["source"] as? String == "directory")
        #expect(source["path"] as? String == "/abs/ClaudePlugin")

        let enabled = try #require(obj["enabledPlugins"] as? [String: Any])
        #expect(enabled["mcduck@mcduck"] as? Bool == true)
    }

    @Test("existing unrelated settings are preserved")
    func preservesExistingKeys() throws {
        let existing = #"{"model":"opus","permissions":{"allow":["Bash"]}}"#.data(using: .utf8)
        let obj = try parse(ClaudePluginSettings.merged(intoExisting: existing, marketplacePath: "/p"))

        #expect(obj["model"] as? String == "opus")
        #expect(obj["permissions"] as? [String: Any] != nil)
        #expect(obj["extraKnownMarketplaces"] as? [String: Any] != nil)
        #expect((obj["enabledPlugins"] as? [String: Any])?["mcduck@mcduck"] as? Bool == true)
    }

    @Test("an existing enabledPlugins map keeps its other entries")
    func mergesIntoExistingPlugins() throws {
        let existing = #"{"enabledPlugins":{"other@m":true}}"#.data(using: .utf8)
        let enabled = try #require(try parse(ClaudePluginSettings.merged(intoExisting: existing, marketplacePath: "/p"))["enabledPlugins"] as? [String: Any])

        #expect(enabled["other@m"] as? Bool == true)
        #expect(enabled["mcduck@mcduck"] as? Bool == true)
    }

    @Test("malformed settings throw rather than corrupting the file")
    func malformedThrows() {
        let bad = "not json".data(using: .utf8)
        #expect(throws: PluginInstallError.malformedSettings) {
            try ClaudePluginSettings.merged(intoExisting: bad, marketplacePath: "/p")
        }
    }

    @Test("CLI argument vectors")
    func argumentVectors() {
        #expect(ClaudePluginSettings.marketplaceAddArguments(path: "/p") == ["plugin", "marketplace", "add", "/p"])
        #expect(ClaudePluginSettings.installArguments() == ["plugin", "install", "mcduck@mcduck"])
    }
}

// MARK: - Installer orchestration

@Suite("plugin installer")
struct PluginInstallerTests {
    @Test("CLI success installs via CLI and does not touch settings")
    func cliSuccess() async {
        let io = InMemorySettingsIO()
        let result = await installer(claude: "/usr/bin/claude", runner: ScriptedRunner(addExit: 0, installExit: 0), io: io).install()
        #expect(result == .installedViaCLI)
        #expect(io.wroteCount == 0)
    }

    @Test("a failed CLI add falls back to writing settings")
    func cliAddFailsFallsBack() async {
        let io = InMemorySettingsIO()
        let result = await installer(claude: "/usr/bin/claude", runner: ScriptedRunner(addExit: 1), io: io).install()
        if case .wroteSettings = result {} else { Issue.record("expected wroteSettings, got \(result)") }
        #expect(io.wroteCount == 1)
    }

    @Test("a failed CLI install falls back to writing settings")
    func cliInstallFailsFallsBack() async {
        let io = InMemorySettingsIO()
        let result = await installer(claude: "/usr/bin/claude", runner: ScriptedRunner(addExit: 0, installExit: 1), io: io).install()
        if case .wroteSettings = result {} else { Issue.record("expected wroteSettings, got \(result)") }
        #expect(io.wroteCount == 1)
    }

    @Test("no claude binary writes settings directly")
    func noClaudeWritesSettings() async throws {
        let io = InMemorySettingsIO()
        let result = await installer(claude: nil, io: io).install()
        if case .wroteSettings = result {} else { Issue.record("expected wroteSettings, got \(result)") }
        // The written file carries the registration.
        let enabled = try #require(try parse(io.stored)["enabledPlugins"] as? [String: Any])
        #expect(enabled["mcduck@mcduck"] as? Bool == true)
    }

    @Test("a missing bundled marketplace fails clearly")
    func missingMarketplaceFails() async {
        let result = await installer(claude: nil, marketplacePath: nil).install()
        if case .failed = result {} else { Issue.record("expected failed, got \(result)") }
    }

    @Test("a settings write error surfaces as failed")
    func writeErrorFails() async {
        let io = InMemorySettingsIO()
        io.writeError = WriteFailure.denied
        let result = await installer(claude: nil, io: io).install()
        if case .failed = result {} else { Issue.record("expected failed, got \(result)") }
    }
}
