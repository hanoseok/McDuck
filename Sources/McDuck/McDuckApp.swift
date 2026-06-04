import SwiftUI

@main
struct McDuckApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        // MenuBarIcon comes from the asset catalog compiled into the app's main
        // bundle (Assets.car) by build-app.sh.
        MenuBarExtra("McDuck", image: "MenuBarIcon") {
            McDuckPopover(store: store)
                .frame(width: 480)
                .task {
                    store.startAutoRefresh()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
