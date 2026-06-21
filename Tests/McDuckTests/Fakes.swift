import Foundation
import McDuckCore
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

/// Returns fixed plugin outcomes so `SettingsStore` phase transitions can be
/// tested without touching the CLI or settings.json.
struct FakePluginInstaller: PluginInstalling {
    var outcome: PluginInstallOutcome = .wroteSettings(path: "/x/settings.json")
    var installed: Bool = false
    var uninstallOutcome: PluginUninstallOutcome = .wroteSettings(path: "/x/settings.json")

    func install() async -> PluginInstallOutcome { outcome }
    func isInstalled() -> Bool { installed }
    func uninstall() async -> PluginUninstallOutcome { uninstallOutcome }
}

/// Fixed update outcomes so `SettingsStore` can be tested without network or
/// opening macOS Installer.
final class FakeAppUpdater: AppUpdating, @unchecked Sendable {
    var current: InstalledAppVersion?
    var checkResult: AppUpdateCheckResult
    var installResult: AppUpdateInstallResult
    private(set) var checkCount = 0
    private(set) var installCount = 0

    init(
        current: InstalledAppVersion?,
        checkResult: AppUpdateCheckResult,
        installResult: AppUpdateInstallResult = .failed("not configured")
    ) {
        self.current = current
        self.checkResult = checkResult
        self.installResult = installResult
    }

    func currentInstalledVersion() -> InstalledAppVersion? {
        current
    }

    func checkForUpdate() async -> AppUpdateCheckResult {
        checkCount += 1
        return checkResult
    }

    func installUpdate(_ release: AppUpdateRelease) async -> AppUpdateInstallResult {
        installCount += 1
        return installResult
    }
}

/// A throwaway, isolated UserDefaults so settings tests never read or write the
/// real app domain.
func makeEphemeralDefaults() -> UserDefaults {
    let suite = "McDuckTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
