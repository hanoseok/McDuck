import SwiftUI

@main
struct McDuckApp: App {
    @State private var store = UsageStore()
    @State private var settings = SettingsStore()

    var body: some Scene {
        // MenuBarIcon comes from the asset catalog compiled into the app's main
        // bundle (Assets.car) by build-app.sh.
        MenuBarExtra("McDuck", image: "MenuBarIcon") {
            McDuckPopover(store: store, settings: settings)
                .frame(width: 480)
                .task {
                    store.startAutoRefresh()
                    settings.refreshLoginItemState()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
