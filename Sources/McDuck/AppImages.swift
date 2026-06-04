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
        guard let base = appIcon else {
            return NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "McDuck")
                ?? NSImage()
        }
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        image.isTemplate = false
        return image
    }()
}
