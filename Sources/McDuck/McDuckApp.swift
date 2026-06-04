import SwiftUI

@main
struct McDuckApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra("McDuck", systemImage: "chart.bar.xaxis") {
            McDuckPopover(store: store)
                .frame(width: 480)
                .task {
                    store.startAutoRefresh()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
