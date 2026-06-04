import SwiftUI

@main
struct McDuckApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            McDuckPopover(store: store)
                .frame(width: 480)
                .task {
                    store.startAutoRefresh()
                }
        } label: {
            // Named image from the compiled asset catalog in the module bundle.
            Image("MenuBarIcon", bundle: .module)
        }
        .menuBarExtraStyle(.window)
    }
}
