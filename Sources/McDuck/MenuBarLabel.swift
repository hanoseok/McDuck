import SwiftUI

/// The menu-bar status item: the McDuck icon plus the selected period's metric(s).
///
/// The icon + text are rendered together into ONE template `NSImage`. (A split
/// label of a live icon next to an `Image(nsImage:)` does not render the text in
/// the menu bar; a single composite image does.) The text is kept smaller than
/// the icon so the icon drives the composite height and therefore stays at the
/// menu-bar height — it doesn't shrink when text is shown.
struct MenuBarLabel: View {
    let store: UsageStore
    let settings: SettingsStore

    private static let iconHeight: CGFloat = 20

    var body: some View {
        if settings.menuBarPeriod != .none,
           let usage = store.menuBarUsage(for: settings.menuBarPeriod),
           let image = Self.render(usage: usage, metric: settings.menuBarMetric) {
            Image(nsImage: image)
        } else {
            Image("MenuBarIcon")
        }
    }

    @MainActor
    private static func render(
        usage: (tokens: String, cost: String),
        metric: MenuBarMetric
    ) -> NSImage? {
        let lines: [String]
        switch metric {
        case .token: lines = [usage.tokens]
        case .cost: lines = [usage.cost]
        case .both: lines = [usage.tokens, usage.cost]
        }

        let content = HStack(spacing: 3) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconHeight, height: iconHeight)
            VStack(alignment: .trailing, spacing: -1) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                }
            }
            // Smaller than the icon so the icon, not the text, sets the height.
            .font(.system(size: metric == .both ? 8 : 11, weight: .medium))
        }

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}
