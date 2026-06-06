import Foundation
import McDuckCore

/// Result of trying to register/enable the bundled McDuck plugin in Claude Code.
enum PluginInstallOutcome: Equatable, Sendable {
    /// The `claude` CLI registered + installed the plugin.
    case installedViaCLI
    /// Fallback: wrote the registration into the user's settings.json.
    case wroteSettings(path: String)
    /// Could not register the plugin.
    case failed(message: String)
}

/// Abstraction so the settings UI can be driven by a fake in tests.
protocol PluginInstalling: Sendable {
    func install() async -> PluginInstallOutcome
}

/// The marketplace/plugin identifiers and the exact settings.json shapes Claude
/// Code expects. Kept pure (no I/O) so the JSON merge is unit-testable.
enum ClaudePluginSettings {
    /// Must match the `name` in the bundled `.claude-plugin/marketplace.json`.
    static let marketplaceName = "mcduck"
    /// `<plugin>@<marketplace>` enable key.
    static let pluginRef = "mcduck@mcduck"

    /// Merges the marketplace registration (`extraKnownMarketplaces`, a local
    /// `directory` source) and plugin enablement (`enabledPlugins`) into existing
    /// settings.json bytes, preserving every other key. Pass `nil`/empty for a
    /// fresh file.
    static func merged(intoExisting data: Data?, marketplacePath: String) throws -> Data {
        var root: [String: Any] = [:]
        if let data, !data.isEmpty {
            // Any parse failure (invalid JSON or a non-object top level) is a
            // malformed-settings error rather than a leaked Cocoa error.
            guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                throw PluginInstallError.malformedSettings
            }
            root = object
        }

        var marketplaces = root["extraKnownMarketplaces"] as? [String: Any] ?? [:]
        marketplaces[marketplaceName] = [
            "source": ["source": "directory", "path": marketplacePath]
        ]
        root["extraKnownMarketplaces"] = marketplaces

        var enabled = root["enabledPlugins"] as? [String: Any] ?? [:]
        enabled[pluginRef] = true
        root["enabledPlugins"] = enabled

        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// `claude plugin marketplace add <path>` arguments.
    static func marketplaceAddArguments(path: String) -> [String] {
        ["plugin", "marketplace", "add", path]
    }

    /// `claude plugin install mcduck@mcduck` arguments.
    static func installArguments() -> [String] {
        ["plugin", "install", pluginRef]
    }
}

enum PluginInstallError: Error, Equatable {
    case malformedSettings
}

/// Reads/writes the Claude settings.json. Injectable so tests don't touch
/// `~/.claude`.
protocol SettingsFileIO: Sendable {
    func read(_ url: URL) -> Data?
    func write(_ data: Data, to url: URL) throws
}

struct FileManagerSettingsIO: SettingsFileIO {
    func read(_ url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}

/// Finds the `claude` binary in the locations its installers use, since a GUI
/// app launches with a minimal PATH.
enum ClaudeLocator {
    static func locate(
        fileManager: FileManager = .default,
        home: String = NSHomeDirectory()
    ) -> String? {
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        return candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }
}

/// Registers + enables the bundled plugin in Claude Code. Tries the `claude` CLI
/// first; on any failure (including no CLI), falls back to writing the
/// registration into the user's settings.json.
struct PluginInstaller: PluginInstalling {
    let runner: any CommandRunner
    /// Resolved `claude` binary path, or nil if not found.
    let claudeExecutable: String?
    /// Absolute path to the bundled marketplace dir, or nil if unbundled.
    let marketplacePath: String?
    let settingsURL: URL
    let fileIO: any SettingsFileIO

    func install() async -> PluginInstallOutcome {
        guard let marketplacePath else {
            return .failed(message: "The bundled marketplace was not found. Run from the installed McDuck app.")
        }

        if let claudeExecutable {
            let environment = ["PATH": pathValue(forClaude: claudeExecutable)]
            let add = await runner.run(CommandRequest(
                executable: claudeExecutable,
                arguments: ClaudePluginSettings.marketplaceAddArguments(path: marketplacePath),
                environment: environment,
                timeout: 60
            ))
            if add.exitCode == 0 {
                let install = await runner.run(CommandRequest(
                    executable: claudeExecutable,
                    arguments: ClaudePluginSettings.installArguments(),
                    environment: environment,
                    timeout: 120
                ))
                if install.exitCode == 0 {
                    return .installedViaCLI
                }
            }
            // CLI present but did not work (e.g. no non-interactive subcommand):
            // fall through to the settings-file fallback.
        }

        do {
            let merged = try ClaudePluginSettings.merged(
                intoExisting: fileIO.read(settingsURL),
                marketplacePath: marketplacePath
            )
            try fileIO.write(merged, to: settingsURL)
            return .wroteSettings(path: settingsURL.path)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    private func pathValue(forClaude claude: String) -> String {
        let base = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        let dir = (claude as NSString).deletingLastPathComponent
        return dir.isEmpty ? base : "\(dir):\(base)"
    }
}
