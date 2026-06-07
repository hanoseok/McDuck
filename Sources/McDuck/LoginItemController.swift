import Foundation
import ServiceManagement

/// Observable state of the "launch at login" registration. Kept independent of
/// `SMAppService.Status` so the UI and tests don't depend on the macOS-only type.
enum LoginItemState: Equatable {
    /// Registered and will launch at login.
    case enabled
    /// Not registered.
    case disabled
    /// Registered, but the user must approve it in System Settings > Login Items.
    case requiresApproval
    /// Login-item control is unavailable (e.g. app not installed as a bundle).
    case unavailable

    var isOn: Bool { self == .enabled }
}

/// Abstraction over the login-item registration so the settings layer can be
/// driven by a fake in tests/previews without touching ServiceManagement.
protocol LoginItemControlling: Sendable {
    /// Current registration state, read fresh from the system.
    func currentState() -> LoginItemState
    /// Registers (`true`) or unregisters (`false`) the app as a login item.
    func setEnabled(_ enabled: Bool) throws
    /// Opens System Settings to the Login Items pane for manual approval.
    func openSettings()
}

/// Concrete login-item control backed by `SMAppService.mainApp` (macOS 13+).
/// No helper bundle is required; this registers the main app itself, which is
/// compatible with the `LSUIElement` menu-bar app and ad-hoc signing.
struct SMAppServiceLoginItem: LoginItemControlling {
    func currentState() -> LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            // `.notFound` is common for ad-hoc-signed or relocated apps, but
            // registering can still work (and if it can't, the error from
            // register() is far more useful than hiding the control). So treat
            // it as "not registered yet" and let the user try.
            return .disabled
        @unknown default:
            return .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
