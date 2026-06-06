import SwiftUI

/// The menu-bar status item label: the McDuck icon with the selected period's
/// tokens (top) and cost (bottom) stacked.
///
/// The two lines are rendered into a template `NSImage` rather than laid out as
/// live `Text`, because the menu bar is one row tall and clips live two-line
/// text to just the top line. An image is scaled to the bar height, so both
/// lines stay visible. Falls back to the plain icon for `.none` / no data.
struct MenuBarLabel: View {
    let store: UsageStore
    let settings: SettingsStore

    var body: some View {
        if settings.menuBarPeriod != .none,
           let usage = store.menuBarUsage(for: settings.menuBarPeriod),
           let image = Self.render(tokens: usage.tokens, cost: usage.cost) {
            Image(nsImage: image)
        } else {
            Image("MenuBarIcon")
        }
    }

    /// Renders the icon + stacked tokens/cost to a template image that the menu
    /// bar scales to fit its height.
    @MainActor
    private static func render(tokens: String, cost: String) -> NSImage? {
        let content = HStack(spacing: 3) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
            VStack(alignment: .trailing, spacing: -1) {
                Text(tokens)
                Text(cost)
            }
            .font(.system(size: 9, weight: .medium))
        }

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            return nil
        }
        // Template so the icon + text adapt to the menu bar's light/dark style.
        image.isTemplate = true
        return image
    }
}
