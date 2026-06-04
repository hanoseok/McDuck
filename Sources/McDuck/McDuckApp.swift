import SwiftUI

@main
struct McDuckApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        // The asset catalog is compiled into the main bundle (build-app.sh), so
        // the image name resolves via the main bundle here.
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
