import SwiftUI

/// The menu-bar status item label: the McDuck icon, optionally followed by
/// today's cost or token total so usage is visible without opening the popover.
/// Falls back to the icon alone while data is still loading.
struct MenuBarLabel: View {
    let store: UsageStore
    let settings: SettingsStore

    var body: some View {
        switch settings.menuBarDisplay {
        case .icon:
            icon
        case .cost:
            labeled(store.menuBarCostText)
        case .tokens:
            labeled(store.menuBarTokensText)
        }
    }

    private var icon: some View {
        Image("MenuBarIcon")
    }

    @ViewBuilder
    private func labeled(_ text: String?) -> some View {
        if let text {
            HStack(spacing: 3) {
                icon
                Text(text)
            }
        } else {
            icon
        }
    }
}
