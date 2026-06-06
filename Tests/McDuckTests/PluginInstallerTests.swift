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
    var uninstallExit: Int32 = 0
    var removeExit: Int32 = 0

    func run(_ request: CommandRequest) async -> CommandResult {
        let args = request.arguments
        // "uninstall"/"remove" are checked first; they are distinct elements
        // from "install"/"add".
        if args.contains("uninstall") {
            return CommandResult(exitCode: uninstallExit, stdout: "", stderr: uninstallExit == 0 ? "" : "uninstall failed")
        }
        if args.contains("remove") {
            return CommandResult(exitCode: removeExit, stdout: "", stderr: removeExit == 0 ? "" : "remove failed")
        }
        if args.contains("add") {
            return CommandResult(exitCode: addExit, stdout: "", stderr: addExit == 0 ? "" : "add failed")
        }
        if args.contains("install") {
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
        #expect(ClaudePluginSettings.uninstallArguments() == ["plugin", "uninstall", "mcduck@mcduck"])
        #expect(ClaudePluginSettings.marketplaceRemoveArguments() == ["plugin", "marketplace", "remove", "mcduck"])
    }

    // MARK: - Installed detection

    @Test("isInstalled is false for empty or unrelated settings")
    func notInstalled() {
        #expect(ClaudePluginSettings.isInstalled(in: nil) == false)
        #expect(ClaudePluginSettings.isInstalled(in: #"{"model":"opus"}"#.data(using: .utf8)) == false)
    }

    @Test("isInstalled is true when the plugin is enabled or the marketplace is known")
    func installedDetected() {
        #expect(ClaudePluginSettings.isInstalled(in: #"{"enabledPlugins":{"mcduck@mcduck":true}}"#.data(using: .utf8)))
        #expect(ClaudePluginSettings.isInstalled(in: #"{"extraKnownMarketplaces":{"mcduck":{}}}"#.data(using: .utf8)))
    }

    // MARK: - Removal

    @Test("removed strips the marketplace and plugin entries, keeping others")
    func removedStripsEntries() throws {
        let installed = try ClaudePluginSettings.merged(intoExisting: #"{"model":"opus"}"#.data(using: .utf8), marketplacePath: "/p")
        let cleaned = try parse(ClaudePluginSettings.removed(fromExisting: installed))

        #expect(cleaned["model"] as? String == "opus")
        #expect((cleaned["enabledPlugins"] as? [String: Any])?["mcduck@mcduck"] == nil)
        #expect((cleaned["extraKnownMarketplaces"] as? [String: Any])?["mcduck"] == nil)
        #expect(ClaudePluginSettings.isInstalled(in: try ClaudePluginSettings.removed(fromExisting: installed)) == false)
    }

    @Test("removed is a no-op when nothing is installed")
    func removedIdempotent() throws {
        let cleaned = try parse(ClaudePluginSettings.removed(fromExisting: #"{"model":"opus"}"#.data(using: .utf8)))
        #expect(cleaned["model"] as? String == "opus")
    }
}

@Suite("plugin uninstaller")
struct PluginUninstallerTests {
    @Test("installer reports installed state from settings.json")
    func isInstalledReadsSettings() {
        let io = InMemorySettingsIO(stored: #"{"enabledPlugins":{"mcduck@mcduck":true}}"#.data(using: .utf8))
        #expect(installer(io: io).isInstalled() == true)
        #expect(installer(io: InMemorySettingsIO()).isInstalled() == false)
    }

    @Test("CLI uninstall removes via CLI without touching settings")
    func cliUninstall() async {
        let io = InMemorySettingsIO(stored: #"{"enabledPlugins":{"mcduck@mcduck":true}}"#.data(using: .utf8))
        let result = await installer(claude: "/usr/bin/claude", runner: ScriptedRunner(), io: io).uninstall()
        #expect(result == .removedViaCLI)
        #expect(io.wroteCount == 0)
    }

    @Test("with no claude, uninstall rewrites settings without the entries")
    func settingsUninstall() async throws {
        let io = InMemorySettingsIO(stored: #"{"model":"opus","enabledPlugins":{"mcduck@mcduck":true}}"#.data(using: .utf8))
        let result = await installer(claude: nil, io: io).uninstall()
        if case .wroteSettings = result {} else { Issue.record("expected wroteSettings, got \(result)") }

        let obj = try parse(io.stored)
        #expect(obj["model"] as? String == "opus")
        #expect((obj["enabledPlugins"] as? [String: Any])?["mcduck@mcduck"] == nil)
    }

    @Test("a settings write error surfaces as failed")
    func uninstallWriteErrorFails() async {
        let io = InMemorySettingsIO(stored: #"{"enabledPlugins":{"mcduck@mcduck":true}}"#.data(using: .utf8))
        io.writeError = WriteFailure.denied
        let result = await installer(claude: nil, io: io).uninstall()
        if case .failed = result {} else { Issue.record("expected failed, got \(result)") }
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
