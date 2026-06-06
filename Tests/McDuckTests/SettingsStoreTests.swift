import Foundation
import Testing
@testable import McDuck

/// Regression coverage for the settings layer: the menu-bar display preference
/// (default + persistence) and the launch-at-login toggle behavior.
@Suite("settings store")
@MainActor
struct SettingsStoreTests {
    // MARK: - Menu bar period

    @Test("menu bar period defaults to today when nothing is stored")
    func defaultsToToday() {
        let settings = SettingsStore(loginItem: FakeLoginItem(), defaults: makeEphemeralDefaults())
        #expect(settings.menuBarPeriod == .today)
    }

    @Test("the period options are exactly none/today/week/month/total")
    func periodOptions() {
        #expect(MenuBarPeriod.allCases == [.none, .today, .week, .month, .total])
    }

    @Test("setMenuBarPeriod updates the value and persists it across instances")
    func persistsMenuBarPeriod() {
        let defaults = makeEphemeralDefaults()
        let settings = SettingsStore(loginItem: FakeLoginItem(), defaults: defaults)

        settings.setMenuBarPeriod(.week)
        #expect(settings.menuBarPeriod == .week)

        // A fresh store reading the same defaults should restore the choice.
        let reloaded = SettingsStore(loginItem: FakeLoginItem(), defaults: defaults)
        #expect(reloaded.menuBarPeriod == .week)
    }

    @Test("an unrecognized stored value falls back to today")
    func unknownStoredValueFallsBack() {
        let defaults = makeEphemeralDefaults()
        defaults.set("nonsense", forKey: "menuBarPeriod")
        let settings = SettingsStore(loginItem: FakeLoginItem(), defaults: defaults)
        #expect(settings.menuBarPeriod == .today)
    }

    // MARK: - Launch at login

    @Test("enabling launch at login reflects the enabled state")
    func enableLogin() {
        let fake = FakeLoginItem(state: .disabled)
        let settings = SettingsStore(loginItem: fake, defaults: makeEphemeralDefaults())

        settings.setLaunchAtLogin(true)

        #expect(fake.lastSetEnabled == true)
        #expect(settings.launchAtLogin)
        #expect(settings.loginItemState == .enabled)
        #expect(settings.loginItemError == nil)
    }

    @Test("disabling launch at login clears the registration")
    func disableLogin() {
        let fake = FakeLoginItem(state: .enabled)
        let settings = SettingsStore(loginItem: fake, defaults: makeEphemeralDefaults())

        settings.setLaunchAtLogin(false)

        #expect(fake.lastSetEnabled == false)
        #expect(settings.launchAtLogin == false)
        #expect(settings.loginItemState == .disabled)
    }

    @Test("a failed registration surfaces an error and leaves the toggle off")
    func failedRegistrationSurfacesError() {
        let fake = FakeLoginItem(state: .disabled)
        fake.setEnabledError = FakeError.registrationFailed
        let settings = SettingsStore(loginItem: fake, defaults: makeEphemeralDefaults())

        settings.setLaunchAtLogin(true)

        #expect(settings.loginItemError != nil)
        #expect(settings.launchAtLogin == false)
    }

    @Test("requiresApproval is reported while the control stays available")
    func requiresApproval() {
        let settings = SettingsStore(loginItem: FakeLoginItem(state: .requiresApproval), defaults: makeEphemeralDefaults())
        #expect(settings.loginItemNeedsApproval)
        #expect(settings.isLoginItemAvailable)
    }

    @Test("an unavailable login item hides the control")
    func unavailableHidesControl() {
        let settings = SettingsStore(loginItem: FakeLoginItem(state: .unavailable), defaults: makeEphemeralDefaults())
        #expect(settings.isLoginItemAvailable == false)
    }

    @Test("opening login items settings is forwarded to the controller")
    func opensSettings() {
        let fake = FakeLoginItem()
        let settings = SettingsStore(loginItem: fake, defaults: makeEphemeralDefaults())
        settings.openLoginItemsSettings()
        #expect(fake.openSettingsCount == 1)
    }

    // MARK: - Plugin install

    private func store(installer: FakePluginInstaller) -> SettingsStore {
        SettingsStore(loginItem: FakeLoginItem(), defaults: makeEphemeralDefaults(), pluginInstaller: installer)
    }

    @Test("installing via the settings fallback reports done")
    func installWroteSettings() async {
        let settings = store(installer: FakePluginInstaller(outcome: .wroteSettings(path: "/x/settings.json")))
        await settings.installPlugin()
        if case .done = settings.pluginInstallPhase {} else { Issue.record("expected done, got \(settings.pluginInstallPhase)") }
    }

    @Test("installing via the CLI reports done")
    func installViaCLI() async {
        let settings = store(installer: FakePluginInstaller(outcome: .installedViaCLI))
        await settings.installPlugin()
        if case .done = settings.pluginInstallPhase {} else { Issue.record("expected done, got \(settings.pluginInstallPhase)") }
    }

    @Test("a failed install surfaces the failure")
    func installFailed() async {
        let settings = store(installer: FakePluginInstaller(outcome: .failed(message: "nope")))
        await settings.installPlugin()
        #expect(settings.pluginInstallPhase == .failed("nope"))
    }

    @Test("installed state is detected at init")
    func detectsInstalled() {
        #expect(store(installer: FakePluginInstaller(installed: true)).isPluginInstalled)
        #expect(store(installer: FakePluginInstaller(installed: false)).isPluginInstalled == false)
    }

    @Test("uninstalling reports done")
    func uninstallReportsDone() async {
        let settings = store(installer: FakePluginInstaller(installed: true, uninstallOutcome: .removedViaCLI))
        await settings.uninstallPlugin()
        if case .done = settings.pluginInstallPhase {} else { Issue.record("expected done, got \(settings.pluginInstallPhase)") }
    }

    @Test("a failed uninstall surfaces the failure")
    func uninstallFailed() async {
        let settings = store(installer: FakePluginInstaller(installed: true, uninstallOutcome: .failed(message: "boom")))
        await settings.uninstallPlugin()
        #expect(settings.pluginInstallPhase == .failed("boom"))
    }
}
