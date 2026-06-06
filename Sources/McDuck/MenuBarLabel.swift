import SwiftUI

/// The menu-bar status item label: the McDuck icon, optionally followed by the
/// selected period's tokens (top) and cost (bottom). Falls back to the icon
/// alone for the `.none` period or until data is available.
struct MenuBarLabel: View {
    let store: UsageStore
    let settings: SettingsStore

    var body: some View {
        if settings.menuBarPeriod == .none {
            icon
        } else if let usage = store.menuBarUsage(for: settings.menuBarPeriod) {
            HStack(spacing: 3) {
                icon
                VStack(alignment: .leading, spacing: 0) {
                    Text(usage.tokens)
                    Text(usage.cost)
                }
                .font(.system(size: 9))
            }
        } else {
            icon
        }
    }

    private var icon: some View {
        Image("MenuBarIcon")
    }
}
