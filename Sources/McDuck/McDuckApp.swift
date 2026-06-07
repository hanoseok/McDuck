import SwiftUI

@main
struct McDuckApp: App {
    @State private var store = UsageStore()
    @State private var settings = SettingsStore()

    var body: some Scene {
        // MenuBarIcon comes from the asset catalog compiled into the app's main
        // bundle (Assets.car) by build-app.sh. The label can additionally show
        // today's cost/tokens depending on the user's menu-bar setting.
        MenuBarExtra {
            McDuckPopover(store: store, settings: settings)
                .frame(width: 480)
                .task {
                    settings.refreshLoginItemState()
                }
        } label: {
            // The label is always present (the popover content is only built when
            // opened), so start the background fetch here. That way ccusage is
            // pulled at launch — the menu-bar numbers are ready without opening
            // the popover.
            MenuBarLabel(store: store, settings: settings)
                .task { store.startAutoRefresh() }
        }
        .menuBarExtraStyle(.window)
    }
}
