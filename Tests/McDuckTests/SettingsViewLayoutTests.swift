import Foundation
import Testing

@Suite("settings view layout")
struct SettingsViewLayoutTests {
    @Test("settings shows version and update controls above quit")
    func settingsShowsVersionAndUpdateControlsAboveQuit() throws {
        let source = try String(contentsOf: settingsViewURL(), encoding: .utf8)
        let versionSection = try #require(source.range(of: #"Text("Version")"#))
        let checkForUpdates = try #require(source.range(of: #"Label("Check for Updates", systemImage: "arrow.clockwise")"#))
        let quit = try #require(source.range(of: #"Label("Quit", systemImage: "power")"#))

        #expect(versionSection.lowerBound < checkForUpdates.lowerBound)
        #expect(checkForUpdates.lowerBound < quit.lowerBound)
        #expect(source.contains("settings.currentAppVersionText"))
        #expect(source.contains("settings.currentAppUpdateChannelTitle"))
        #expect(source.contains("settings.checkForUpdates()"))
    }

    @Test("main popover footer shows ccusage time icon action and update only when available")
    func mainPopoverFooterShowsCcusageTimeIconActionAndAvailableUpdateOnly() throws {
        let source = try String(contentsOf: mcDuckPopoverURL(), encoding: .utf8)
        let footer = try footerSource(in: source)
        let oldVisibleLabel = "Re" + "fresh"
        let oldHelpText = oldVisibleLabel + " usage"

        #expect(footer.contains("Text(\"Updated \\("))
        #expect(footer.contains("lastUpdated.formatted(date: .omitted, time: .shortened)"))
        #expect(footer.contains(#"Image(systemName: "arrow.clockwise")"#))
        #expect(!footer.contains(#"Label("\#(oldVisibleLabel)", systemImage: "arrow.clockwise")"#))
        #expect(footer.contains("await store.refresh(quiet: true)"))
        #expect(!footer.contains("settings.checkForUpdates()"))
        #expect(footer.contains(#".help("Reload usage")"#))
        #expect(!footer.contains(#".help("\#(oldHelpText)")"#))
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
