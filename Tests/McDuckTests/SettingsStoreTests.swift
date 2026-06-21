import Foundation
import Testing
import McDuckCore
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

    @Test("menu bar metric options are token/cost/both and default to both")
    func metricOptionsAndDefault() {
        #expect(MenuBarMetric.allCases == [.token, .cost, .both])
        #expect(SettingsStore(loginItem: FakeLoginItem(), defaults: makeEphemeralDefaults()).menuBarMetric == .both)
    }

    @Test("setMenuBarMetric persists across instances")
    func persistsMenuBarMetric() {
        let defaults = makeEphemeralDefaults()
        let settings = SettingsStore(loginItem: FakeLoginItem(), defaults: defaults)
        settings.setMenuBarMetric(.token)
        #expect(SettingsStore(loginItem: FakeLoginItem(), defaults: defaults).menuBarMetric == .token)
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

    private func store(updater: FakeAppUpdater) -> SettingsStore {
        SettingsStore(
            loginItem: FakeLoginItem(),
            defaults: makeEphemeralDefaults(),
            pluginInstaller: FakePluginInstaller(),
            appUpdater: updater
        )
    }

    private func store(
        updater: FakeAppUpdater,
        updateCheckSleep: @escaping @Sendable (Duration) async throws -> Void
    ) -> SettingsStore {
        SettingsStore(
            loginItem: FakeLoginItem(),
            defaults: makeEphemeralDefaults(),
            pluginInstaller: FakePluginInstaller(),
            appUpdater: updater,
            updateCheckSleep: updateCheckSleep
        )
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

    // MARK: - App updates

    @Test("current update channel and version come from the updater")
    func currentUpdateVersion() throws {
        let current = try InstalledAppVersion("1.2.1-SNAPSHOT")
        let settings = store(updater: FakeAppUpdater(
            current: current,
            checkResult: .failed("unused")
        ))

        #expect(settings.currentAppVersionText == "1.2.1-SNAPSHOT")
        #expect(settings.currentAppUpdateChannelTitle == "Snapshot")
    }

    @Test("checking for updates reports an available release")
    func checkReportsAvailableUpdate() async throws {
        let current = try InstalledAppVersion("1.1")
        let release = try updateRelease("1.2")
        let updater = FakeAppUpdater(
            current: current,
            checkResult: .available(current: current, latest: release)
        )
        let settings = store(updater: updater)

        await settings.checkForUpdates()

        #expect(updater.checkCount == 1)
        #expect(settings.updatePhase == .available(release))
    }

    @Test("checking for updates reports up to date")
    func checkReportsUpToDate() async throws {
        let current = try InstalledAppVersion("1.2")
        let release = try updateRelease("1.2")
        let settings = store(updater: FakeAppUpdater(
            current: current,
            checkResult: .upToDate(current: current, latest: release)
        ))

        await settings.checkForUpdates()

        #expect(settings.updatePhase == .upToDate("McDuck 1.2 is up to date."))
    }

    @Test("checking for updates surfaces failures")
    func checkFailure() async throws {
        let settings = store(updater: FakeAppUpdater(
            current: try InstalledAppVersion("1.2"),
            checkResult: .failed("network down")
        ))

        await settings.checkForUpdates()

        #expect(settings.updatePhase == .failed("network down"))
    }

    @Test("installing an available update opens the downloaded package")
    func installAvailableUpdate() async throws {
        let current = try InstalledAppVersion("1.1")
        let release = try updateRelease("1.2")
        let updater = FakeAppUpdater(
            current: current,
            checkResult: .available(current: current, latest: release),
            installResult: .openedInstaller(URL(fileURLWithPath: "/tmp/McDuck.pkg"))
        )
        let settings = store(updater: updater)

        await settings.checkForUpdates()
        await settings.installAvailableUpdate()

        #expect(updater.installCount == 1)
        #expect(settings.updatePhase == .installerOpened("Installer opened. Follow the macOS prompts to finish updating."))
    }

    @Test("automatic update checks run immediately then wait ten minutes and start only once")
    func automaticUpdateChecksRunImmediatelyThenWaitTenMinutesAndStartOnlyOnce() async throws {
        let current = try InstalledAppVersion("1.2")
        let release = try updateRelease("1.2")
        let updater = FakeAppUpdater(
            current: current,
            checkResult: .upToDate(current: current, latest: release)
        )
        let sleepProbe = AutoUpdateSleepProbe()
        let settings = store(updater: updater, updateCheckSleep: sleepProbe.sleep)

        settings.startAutoUpdateChecks()
        let didStart = await eventually {
            await sleepProbe.durations == [.seconds(600)]
        }
        settings.startAutoUpdateChecks()
        await Task.yield()

        #expect(didStart)
        #expect(updater.checkCount == 1)
        #expect(await sleepProbe.durations == [.seconds(600)])
    }

    private func updateRelease(_ version: String) throws -> AppUpdateRelease {
        try AppUpdateRelease.githubRelease(
            data: Data("""
            {
              "tag_name": "\(version)",
              "name": "McDuck-\(version)",
              "prerelease": false,
              "assets": [
                {"name":"McDuck.pkg","browser_download_url":"https://example.com/McDuck.pkg"}
              ]
            }
            """.utf8),
            expectedChannel: .release
        )
    }
}

private actor AutoUpdateSleepProbe {
    private(set) var durations: [Duration] = []

    func sleep(_ duration: Duration) async throws {
        durations.append(duration)
        throw CancellationError()
    }
}

private func eventually(_ condition: @escaping @Sendable () async -> Bool) async -> Bool {
    for _ in 0..<50 {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return false
}
