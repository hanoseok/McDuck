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
                    store.startAutoRefresh()
                    settings.refreshLoginItemState()
                }
        } label: {
            MenuBarLabel(store: store, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
