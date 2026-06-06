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
        case .both:
            both
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

    /// Today's tokens (top) and cost (bottom), stacked to fit the menu-bar
    /// height. Falls back to the icon alone until data is available.
    @ViewBuilder
    private var both: some View {
        if store.menuBarTokensText == nil, store.menuBarCostText == nil {
            icon
        } else {
            HStack(spacing: 3) {
                icon
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.menuBarTokensText ?? "–")
                    Text(store.menuBarCostText ?? "–")
                }
                .font(.system(size: 9))
            }
        }
    }
}
