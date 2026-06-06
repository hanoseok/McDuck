import Foundation
import Testing
@testable import McDuck

/// Regression coverage for the settings layer: the menu-bar display preference
/// (default + persistence) and the launch-at-login toggle behavior.
@Suite("settings store")
@MainActor
struct SettingsStoreTests {
    // MARK: - Menu bar display

    @Test("menu bar display defaults to cost when nothing is stored")
    func defaultsToCost() {
        let settings = SettingsStore(loginItem: FakeLoginItem(), defaults: makeEphemeralDefaults())
        #expect(settings.menuBarDisplay == .cost)
    }

    @Test("setMenuBarDisplay updates the value and persists it across instances")
    func persistsMenuBarDisplay() {
        let defaults = makeEphemeralDefaults()
        let settings = SettingsStore(loginItem: FakeLoginItem(), defaults: defaults)

        settings.setMenuBarDisplay(.tokens)
        #expect(settings.menuBarDisplay == .tokens)

        // A fresh store reading the same defaults should restore the choice.
        let reloaded = SettingsStore(loginItem: FakeLoginItem(), defaults: defaults)
        #expect(reloaded.menuBarDisplay == .tokens)
    }

    @Test("an unrecognized stored value falls back to cost")
    func unknownStoredValueFallsBack() {
        let defaults = makeEphemeralDefaults()
        defaults.set("nonsense", forKey: "menuBarDisplay")
        let settings = SettingsStore(loginItem: FakeLoginItem(), defaults: defaults)
        #expect(settings.menuBarDisplay == .cost)
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
}
