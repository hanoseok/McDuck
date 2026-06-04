import AppKit
import SwiftUI

/// Bundled app images loaded from the SwiftPM resource bundle (Bundle.module).
enum AppImages {
    static let appIcon: NSImage? = Bundle.module
        .url(forResource: "AppIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
}
