import Foundation
@testable import McDuck

/// In-memory `LoginItemControlling` used to drive `SettingsStore` without
/// touching the real `SMAppService` registration.
final class FakeLoginItem: LoginItemControlling, @unchecked Sendable {
    var state: LoginItemState
    /// When set, `setEnabled` throws this instead of changing state.
    var setEnabledError: Error?
    private(set) var lastSetEnabled: Bool?
    private(set) var openSettingsCount = 0

    init(state: LoginItemState = .disabled) {
        self.state = state
    }

    func currentState() -> LoginItemState { state }

    func setEnabled(_ enabled: Bool) throws {
        lastSetEnabled = enabled
        if let setEnabledError {
            throw setEnabledError
        }
        state = enabled ? .enabled : .disabled
    }

    func openSettings() {
        openSettingsCount += 1
    }
}

enum FakeError: Error {
    case registrationFailed
}

/// Returns a fixed plugin-install outcome so `SettingsStore` phase transitions
/// can be tested without touching the CLI or settings.json.
struct FakePluginInstaller: PluginInstalling {
    var outcome: PluginInstallOutcome
    func install() async -> PluginInstallOutcome { outcome }
}

/// A throwaway, isolated UserDefaults so settings tests never read or write the
/// real app domain.
func makeEphemeralDefaults() -> UserDefaults {
    let suite = "McDuckTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
