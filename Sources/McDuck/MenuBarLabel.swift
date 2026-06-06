import SwiftUI

/// The menu-bar status item label: the McDuck icon, optionally followed by the
/// selected period's tokens and cost.
///
/// Both values are shown on a SINGLE line (`tokens · cost`). The macOS menu bar
/// is one row tall (~22pt), so a stacked two-line label gets clipped to just the
/// top line — a single line is the only reliable way to show both. Falls back to
/// the icon alone for the `.none` period or until data is available.
struct MenuBarLabel: View {
    let store: UsageStore
    let settings: SettingsStore

    var body: some View {
        if settings.menuBarPeriod == .none {
            icon
        } else if let usage = store.menuBarUsage(for: settings.menuBarPeriod) {
            HStack(spacing: 4) {
                icon
                Text("\(usage.tokens) · \(usage.cost)")
            }
        } else {
            icon
        }
    }

    private var icon: some View {
        Image("MenuBarIcon")
    }
}
