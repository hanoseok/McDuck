import Foundation
import Testing

@Suite("settings view layout")
struct SettingsViewLayoutTests {
    @Test("settings hosts quit instead of updates")
    func settingsHostsQuitInsteadOfUpdates() throws {
        let source = try String(contentsOf: settingsViewURL(), encoding: .utf8)

        #expect(source.contains(#"Label("Quit", systemImage: "power")"#))
        #expect(!source.contains(#"Text("Updates")"#))
    }

    @Test("main popover footer shows refresh on the left and update only when available")
    func mainPopoverFooterShowsRefreshAndAvailableUpdateOnly() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let footer = try footerSource(in: source)

        #expect(footer.contains(#"Label("Refresh", systemImage: "arrow.clockwise")"#))
        #expect(!footer.contains(#"Text("Updated "#))
        #expect(footer.contains("Text(Self.appVersion)"))
        #expect(footer.contains("if let availableUpdate = settings.availableUpdate"))
        #expect(footer.contains(#"Label("Update", systemImage: "arrow.down.circle")"#))
        #expect(!footer.contains(#"Label("Updates", systemImage: "arrow.down.circle")"#))
        #expect(!footer.contains(#""Up to date""#))
        #expect(!footer.contains(#""Update failed""#))
        #expect(!footer.contains(#"Label("Quit", systemImage: "power")"#))
    }

    private func settingsViewURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/McDuck/SettingsView.swift")
    }

    private func mcDuckPopoverURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/McDuck/McDuckPopover.swift")
    }

    private func footerSource(in source: String) throws -> Substring {
        let footerStart = try #require(source.range(of: "private var footer: some View"))
        let appVersionStart = try #require(source.range(of: "private static var appVersion"))

        return source[footerStart.lowerBound..<appVersionStart.lowerBound]
    }
}
