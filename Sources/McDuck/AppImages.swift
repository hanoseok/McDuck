import AppKit

/// App images loaded from the main bundle's Resources. build-app.sh copies
/// AppIcon.png into the app bundle. (We avoid SwiftPM's Bundle.module here: its
/// resource-bundle accessor crashes in a manually assembled .app bundle.)
enum AppImages {
    static let appIcon: NSImage? = Bundle.main
        .url(forResource: "AppIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
}
