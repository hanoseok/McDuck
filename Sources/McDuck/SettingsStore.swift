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

/// Which metric(s) the menu bar shows for the selected period.
enum MenuBarMetric: String, CaseIterable, Identifiable {
    case token
    case cost
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .token: "Token"
        case .cost: "Cost"
        case .both: "Both"
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

    /// Progress of checking for, downloading, and opening an app update.
    enum AppUpdatePhase: Equatable {
        case idle
        case checking
        case upToDate(String)
        case available(AppUpdateRelease)
        case installing(AppUpdateRelease)
        case installerOpened(String)
        case failed(String)
    }

    private let loginItem: any LoginItemControlling
    private let defaults: UserDefaults
    private let pluginInstaller: any PluginInstalling
    private let appUpdater: any AppUpdating
    @ObservationIgnored private let updateCheckSleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var autoUpdateCheckTask: Task<Void, Never>?
    private static let menuBarPeriodKey = "menuBarPeriod"
    private static let menuBarMetricKey = "menuBarMetric"

    /// Current login-item registration state, synced from the system.
    private(set) var loginItemState: LoginItemState
    /// Last error surfaced while toggling the login item, if any.
    var loginItemError: String?

    /// Which usage window the menu bar shows; persisted across launches. Update
    /// through `setMenuBarPeriod(_:)` so the choice is written to UserDefaults.
    private(set) var menuBarPeriod: MenuBarPeriod

    /// Which metric(s) the menu bar shows; persisted. Update through
    /// `setMenuBarMetric(_:)`.
    private(set) var menuBarMetric: MenuBarMetric

    /// Progress of the "Add to Claude Code" / "Remove" action.
    private(set) var pluginInstallPhase: PluginInstallPhase = .idle

    /// Whether the plugin currently looks registered/enabled in Claude Code.
    private(set) var isPluginInstalled = false

    /// Current app version/channel as read from the installed bundle.
    private(set) var currentAppVersion: InstalledAppVersion?

    /// Progress of the main popover Updates actions.
    private(set) var updatePhase: AppUpdatePhase = .idle

    init(
        loginItem: any LoginItemControlling = SMAppServiceLoginItem(),
        defaults: UserDefaults = .standard,
        pluginInstaller: any PluginInstalling = SettingsStore.defaultPluginInstaller(),
        appUpdater: any AppUpdating = SettingsStore.defaultAppUpdater(),
        updateCheckSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.loginItem = loginItem
        self.defaults = defaults
        self.pluginInstaller = pluginInstaller
        self.appUpdater = appUpdater
        self.updateCheckSleep = updateCheckSleep
        self.loginItemState = loginItem.currentState()
        self.menuBarPeriod = defaults.string(forKey: Self.menuBarPeriodKey)
            .flatMap(MenuBarPeriod.init(rawValue:)) ?? .today
        self.menuBarMetric = defaults.string(forKey: Self.menuBarMetricKey)
            .flatMap(MenuBarMetric.init(rawValue:)) ?? .both
        self.isPluginInstalled = pluginInstaller.isInstalled()
        self.currentAppVersion = appUpdater.currentInstalledVersion()
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

    static func defaultAppUpdater() -> any AppUpdating {
        AppUpdateService()
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

    /// Updates the menu-bar metric choice and persists it.
    func setMenuBarMetric(_ value: MenuBarMetric) {
        menuBarMetric = value
        defaults.set(value.rawValue, forKey: Self.menuBarMetricKey)
    }

    /// True while the plugin registration is running.
    var isInstallingPlugin: Bool {
        pluginInstallPhase == .installing
    }

    var currentAppVersionText: String {
        currentAppVersion?.description ?? "dev"
    }

    var currentAppUpdateChannelTitle: String {
        currentAppVersion?.channel.title ?? "Development"
    }

    var isCheckingForUpdates: Bool {
        updatePhase == .checking
    }

    var isInstallingUpdate: Bool {
        if case .installing = updatePhase {
            return true
        }
        return false
    }

    var availableUpdate: AppUpdateRelease? {
        switch updatePhase {
        case .available(let release), .installing(let release):
            release
        case .idle, .checking, .upToDate, .installerOpened, .failed:
            nil
        }
    }

    /// Re-reads whether the plugin is registered/enabled. Call when the settings
    /// UI appears so a change made elsewhere is reflected.
    func refreshPluginInstalled() {
        isPluginInstalled = pluginInstaller.isInstalled()
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
        refreshPluginInstalled()
    }

    /// Removes the McDuck plugin from Claude Code (CLI first, settings.json
    /// fallback).
    func uninstallPlugin() async {
        guard pluginInstallPhase != .installing else { return }
        pluginInstallPhase = .installing

        switch await pluginInstaller.uninstall() {
        case .removedViaCLI:
            pluginInstallPhase = .done("Removed. Restart Claude Code (or run /reload-plugins).")
        case .wroteSettings:
            pluginInstallPhase = .done("Removed from ~/.claude/settings.json. Restart Claude Code (or run /reload-plugins).")
        case .failed(let message):
            pluginInstallPhase = .failed(message)
        }
        refreshPluginInstalled()
    }

    /// Starts a long-lived loop that checks the app's release channel at launch,
    /// then every ten minutes. The store owns the task so it keeps running while
    /// the popover is closed.
    func startAutoUpdateChecks(interval: Duration = .seconds(600)) {
        guard autoUpdateCheckTask == nil else {
            return
        }

        autoUpdateCheckTask = Task { [weak self] in
            await self?.runAutoUpdateChecks(interval: interval)
        }
    }

    private func runAutoUpdateChecks(interval: Duration) async {
        await checkForUpdates(automatic: true)

        while !Task.isCancelled {
            do {
                try await updateCheckSleep(interval)
            } catch {
                break
            }

            guard !Task.isCancelled else {
                break
            }

            await checkForUpdates(automatic: true)
        }
    }

    func checkForUpdates(automatic: Bool = false) async {
        guard updatePhase != .checking, !isInstallingUpdate else { return }
        if automatic {
            switch updatePhase {
            case .available, .installing, .installerOpened:
                return
            case .idle, .checking, .upToDate, .failed:
                break
            }
        }

        currentAppVersion = appUpdater.currentInstalledVersion()
        updatePhase = .checking

        switch await appUpdater.checkForUpdate() {
        case .available(_, let latest):
            updatePhase = .available(latest)
        case .upToDate(_, let latest):
            updatePhase = .upToDate("McDuck \(latest.version.description) is up to date.")
        case .failed(let message):
            updatePhase = .failed(message)
        }
    }

    func installAvailableUpdate() async {
        guard case .available(let release) = updatePhase else { return }
        updatePhase = .installing(release)

        switch await appUpdater.installUpdate(release) {
        case .openedInstaller:
            updatePhase = .installerOpened("Installer opened. Follow the macOS prompts to finish updating.")
        case .failed(let message):
            updatePhase = .failed(message)
        }
    }
}
