import Foundation
import Testing

@Suite("settings view layout")
struct SettingsViewLayoutTests {
    @Test("updates is the final settings section")
    func updatesIsFinalSection() throws {
        let source = try String(contentsOf: settingsViewURL(), encoding: .utf8)
        let pluginSection = try #require(source.range(of: #"Text("Claude Code plugin")"#))
        let updatesSection = try #require(source.range(of: #"Text("Updates")"#))

        #expect(pluginSection.lowerBound < updatesSection.lowerBound)
    }

    private func settingsViewURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/McDuck/SettingsView.swift")
    }
}
