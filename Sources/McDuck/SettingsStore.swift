import Foundation
import McDuckCore
import Observation

/// What the menu bar shows: a usage window, or nothing (icon only).
enum MenuBarPeriod: String, CaseIterable, Identifiable {
    case none
    case today
    case week
    case month
    case total

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .today: "Today"
        case .week: "Week"
        case .month: "Month"
        case .total: "Total"
        }
    }
}

/// Holds user-facing app settings. Currently the login-item toggle; this is the
/// home for future preferences (refresh interval, budget alerts, currency).
@MainActor
@Observable
final class SettingsStore {
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
    private static let menuBarPeriodKey = "menuBarPeriod"

    /// Current login-item registration state, synced from the system.
    private(set) var loginItemState: LoginItemState
    /// Last error surfaced while toggling the login item, if any.
    var loginItemError: String?

    /// Which usage window the menu bar shows; persisted across launches. Update
    /// through `setMenuBarPeriod(_:)` so the choice is written to UserDefaults.
    private(set) var menuBarPeriod: MenuBarPeriod

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
        self.menuBarPeriod = defaults.string(forKey: Self.menuBarPeriodKey)
            .flatMap(MenuBarPeriod.init(rawValue:)) ?? .today
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

    /// Updates the menu-bar period choice and persists it.
    func setMenuBarPeriod(_ value: MenuBarPeriod) {
        menuBarPeriod = value
        defaults.set(value.rawValue, forKey: Self.menuBarPeriodKey)
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
