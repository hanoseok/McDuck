import Foundation
import McDuckCore
import Observation

/// Holds user-facing app settings. Currently the login-item toggle; this is the
/// home for future preferences (refresh interval, budget alerts, currency).
@MainActor
@Observable
final class SettingsStore {
    /// What the menu-bar item shows next to the icon.
    enum MenuBarDisplay: String, CaseIterable, Identifiable {
        case icon
        case cost
        case tokens
        case both

        var id: String { rawValue }

        /// Short label for the segmented picker.
        var title: String {
            switch self {
            case .icon: "Icon"
            case .cost: "Cost"
            case .tokens: "Tokens"
            case .both: "Both"
            }
        }
    }

    /// Progress of registering the bundled plugin in Claude Code.
    enum PluginInstallPhase: Equatable {
        case idle
        case installing
        case done(String)
        case failed(String)
    }

    private let loginItem: any LoginItemControlling
    private let defaults: UserDefaults
    private let pluginInstaller: any PluginInstalling
    private static let menuBarDisplayKey = "menuBarDisplay"

    /// Current login-item registration state, synced from the system.
    private(set) var loginItemState: LoginItemState
    /// Last error surfaced while toggling the login item, if any.
    var loginItemError: String?

    /// What to show in the menu bar; persisted across launches. Update through
    /// `setMenuBarDisplay(_:)` so the choice is written back to UserDefaults.
    private(set) var menuBarDisplay: MenuBarDisplay

    /// Progress of the "Add to Claude Code" action.
    private(set) var pluginInstallPhase: PluginInstallPhase = .idle

    init(
        loginItem: any LoginItemControlling = SMAppServiceLoginItem(),
        defaults: UserDefaults = .standard,
        pluginInstaller: any PluginInstalling = SettingsStore.defaultPluginInstaller()
    ) {
        self.loginItem = loginItem
        self.defaults = defaults
        self.pluginInstaller = pluginInstaller
        self.loginItemState = loginItem.currentState()
        self.menuBarDisplay = defaults.string(forKey: Self.menuBarDisplayKey)
            .flatMap(MenuBarDisplay.init(rawValue:)) ?? .cost
    }

    /// Builds the real installer: the `claude` CLI plus a settings.json fallback,
    /// using the marketplace bundled inside the app at Resources/ClaudePlugin.
    static func defaultPluginInstaller() -> any PluginInstalling {
        let marketplacePath = Bundle.main.resourceURL?
            .appendingPathComponent("ClaudePlugin", isDirectory: true).path
        let settingsURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/settings.json")
        return PluginInstaller(
            runner: ProcessCommandRunner(),
            claudeExecutable: ClaudeLocator.locate(),
            marketplacePath: marketplacePath,
            settingsURL: settingsURL,
            fileIO: FileManagerSettingsIO()
        )
    }

    /// Whether login-item control is offered at all (hidden when unavailable,
    /// e.g. running an unbundled debug binary).
    var isLoginItemAvailable: Bool {
        loginItemState != .unavailable
    }

    /// Binding-friendly on/off view of the toggle.
    var launchAtLogin: Bool {
        loginItemState.isOn
    }

    /// True when macOS needs the user to approve the item in System Settings.
    var loginItemNeedsApproval: Bool {
        loginItemState == .requiresApproval
    }

    /// Re-reads the live registration state. Call when the settings UI appears
    /// so an out-of-band change (e.g. user toggled it in System Settings) shows.
    func refreshLoginItemState() {
        loginItemState = loginItem.currentState()
    }

    /// Registers/unregisters the login item and reflects the resulting state.
    /// Failures are surfaced via `loginItemError` without changing the toggle.
    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil
        do {
            try loginItem.setEnabled(enabled)
        } catch {
            loginItemError = error.localizedDescription
        }
        loginItemState = loginItem.currentState()
    }

    /// Opens System Settings > Login Items for manual approval.
    func openLoginItemsSettings() {
        loginItem.openSettings()
    }

    /// Updates the menu-bar display choice and persists it.
    func setMenuBarDisplay(_ value: MenuBarDisplay) {
        menuBarDisplay = value
        defaults.set(value.rawValue, forKey: Self.menuBarDisplayKey)
    }

    /// True while the plugin registration is running.
    var isInstallingPlugin: Bool {
        pluginInstallPhase == .installing
    }

    /// Registers + enables the bundled McDuck plugin in Claude Code (CLI first,
    /// settings.json fallback).
    func installPlugin() async {
        guard pluginInstallPhase != .installing else { return }
        pluginInstallPhase = .installing

        switch await pluginInstaller.install() {
        case .installedViaCLI:
            pluginInstallPhase = .done("Installed. Run /reload-plugins or restart Claude Code.")
        case .wroteSettings:
            pluginInstallPhase = .done("Registered in ~/.claude/settings.json. Restart Claude Code (or run /reload-plugins) to load it.")
        case .failed(let message):
            pluginInstallPhase = .failed(message)
        }
    }
}
