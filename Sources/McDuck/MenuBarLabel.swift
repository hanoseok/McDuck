import SwiftUI

/// The menu-bar status item: the McDuck icon plus the selected period's metric(s).
///
/// The icon is a **live** image at a fixed size, so it never changes size whether
/// or not text is shown. Only the text (tokens and/or cost) is rendered to an
/// image — the menu bar clips live two-line text to one row, but an image is
/// scaled to fit, so stacked values stay visible. The icon stays out of that
/// image so it isn't scaled down with the text.
struct MenuBarLabel: View {
    let store: UsageStore
    let settings: SettingsStore

    /// Fixed icon size, used in every state so the icon never resizes.
    private static let iconHeight: CGFloat = 18

    var body: some View {
        if settings.menuBarPeriod != .none,
           let usage = store.menuBarUsage(for: settings.menuBarPeriod),
           let textImage = Self.renderText(usage: usage, metric: settings.menuBarMetric) {
            HStack(spacing: 4) {
                icon
                Image(nsImage: textImage)
            }
        } else {
            icon
        }
    }

    private var icon: some View {
        Image("MenuBarIcon")
            .resizable()
            .scaledToFit()
            .frame(width: Self.iconHeight, height: Self.iconHeight)
    }

    /// Renders just the metric line(s) to a template image (excludes the icon).
    @MainActor
    private static func renderText(
        usage: (tokens: String, cost: String),
        metric: MenuBarMetric
    ) -> NSImage? {
        let lines: [String]
        switch metric {
        case .token: lines = [usage.tokens]
        case .cost: lines = [usage.cost]
        case .both: lines = [usage.tokens, usage.cost]
        }

        let content = VStack(alignment: .trailing, spacing: -1) {
            ForEach(lines, id: \.self) { line in
                Text(line)
            }
        }
        // One value can use a larger font; two stacked values need a smaller one
        // to fit the menu-bar height.
        .font(.system(size: metric == .both ? 8 : 11, weight: .medium))

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}
