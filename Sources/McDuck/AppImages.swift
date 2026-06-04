import AppKit

/// App images loaded from the main bundle's Resources. build-app.sh copies the
/// PNGs into the app bundle. (We avoid SwiftPM's Bundle.module: its
/// resource-bundle accessor crashes in a manually assembled .app bundle.)
enum AppImages {
    /// Popover header ("title") icon.
    static let titleIcon: NSImage? = Bundle.main
        .url(forResource: "McDuck-title", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
}
