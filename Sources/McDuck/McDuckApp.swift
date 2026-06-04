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
            // A named asset-catalog image renders reliably in the menu bar,
            // unlike Image(nsImage:) which often does not appear there.
            Image("MenuBarIcon", bundle: .module)
        }
        .menuBarExtraStyle(.window)
    }
}
