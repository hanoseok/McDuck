import AppKit
import SwiftUI

/// Bundled app images loaded from the SwiftPM resource bundle (Bundle.module).
enum AppImages {
    static let appIcon: NSImage? = Bundle.module
        .url(forResource: "AppIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }

    /// A small, status-bar-sized version of the icon for the menu bar label.
    /// Falls back to an SF Symbol if the bundled image can't be loaded, so the
    /// menu bar item is never invisible.
    static let menuBar: NSImage = {
        // Size the high-resolution image down to the menu bar (keep its reps so
        // it renders crisply; do not re-draw into a blank bitmap).
        if let base = appIcon, let sized = base.copy() as? NSImage {
            sized.size = NSSize(width: 18, height: 18)
            sized.isTemplate = false
            return sized
        }
        let symbol = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "McDuck")
            ?? NSImage()
        symbol.isTemplate = true
        return symbol
    }()
}
