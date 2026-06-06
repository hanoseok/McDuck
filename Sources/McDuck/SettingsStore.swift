import Foundation
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

        var id: String { rawValue }

        /// Short label for the segmented picker.
        var title: String {
            switch self {
            case .icon: "Icon"
            case .cost: "Cost"
            case .tokens: "Tokens"
            }
        }
    }

    private let loginItem: any LoginItemControlling
    private let defaults: UserDefaults
    private static let menuBarDisplayKey = "menuBarDisplay"

    /// Current login-item registration state, synced from the system.
    private(set) var loginItemState: LoginItemState
    /// Last error surfaced while toggling the login item, if any.
    var loginItemError: String?

    /// What to show in the menu bar; persisted across launches. Update through
    /// `setMenuBarDisplay(_:)` so the choice is written back to UserDefaults.
    private(set) var menuBarDisplay: MenuBarDisplay

    init(
        loginItem: any LoginItemControlling = SMAppServiceLoginItem(),
        defaults: UserDefaults = .standard
    ) {
        self.loginItem = loginItem
        self.defaults = defaults
        self.loginItemState = loginItem.currentState()
        self.menuBarDisplay = defaults.string(forKey: Self.menuBarDisplayKey)
            .flatMap(MenuBarDisplay.init(rawValue:)) ?? .cost
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
}
