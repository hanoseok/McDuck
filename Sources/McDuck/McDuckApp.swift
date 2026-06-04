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
            Image(nsImage: AppImages.menuBar)
                .renderingMode(.original)
        }
        .menuBarExtraStyle(.window)
    }
}
