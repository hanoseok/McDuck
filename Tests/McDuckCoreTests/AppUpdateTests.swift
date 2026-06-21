import Foundation
import Testing
@testable import McDuckCore

@Suite("app update domain")
struct AppUpdateTests {
    @Test("release builds only compare against the latest stable release")
    func releaseUpdateAvailability() throws {
        let current = try InstalledAppVersion("1.1")
        let release = try AppUpdateRelease.githubRelease(
            data: stableReleasePayload(tag: "1.2"),
            expectedChannel: .release
        )

        #expect(try AppUpdateAvailability.evaluate(current: current, latest: release) == .available(current: current, latest: release))
    }

    @Test("release builds report up to date when the latest stable version matches")
    func releaseUpToDate() throws {
        let current = try InstalledAppVersion("1.2")
        let release = try AppUpdateRelease.githubRelease(
            data: stableReleasePayload(tag: "1.2"),
            expectedChannel: .release
        )

        #expect(try AppUpdateAvailability.evaluate(current: current, latest: release) == .upToDate(current: current, latest: release))
    }

    @Test("snapshot builds compare against snapshot-latest without using stable releases")
    func snapshotUpdateAvailability() throws {
        let current = try InstalledAppVersion("1.2.0-SNAPSHOT")
        let release = try AppUpdateRelease.githubRelease(
            data: snapshotLatestPayload(version: "1.2.1-SNAPSHOT"),
            expectedChannel: .snapshot
        )

        #expect(release.version.description == "1.2.1-SNAPSHOT")
        #expect(try AppUpdateAvailability.evaluate(current: current, latest: release) == .available(current: current, latest: release))
    }

    @Test("a channel mismatch is rejected instead of suggesting a cross-channel update")
    func channelMismatchRejected() throws {
        let current = try InstalledAppVersion("1.2.0-SNAPSHOT")
        let release = try AppUpdateRelease.githubRelease(
            data: stableReleasePayload(tag: "1.2"),
            expectedChannel: .release
        )

        #expect(throws: AppUpdateError.channelMismatch) {
            try AppUpdateAvailability.evaluate(current: current, latest: release)
        }
    }

    @Test("release payloads must include an installable package asset")
    func missingPackageAssetFails() {
        #expect(throws: AppUpdateError.missingPackageAsset) {
            try AppUpdateRelease.githubRelease(
                data: stableReleasePayload(tag: "1.2", assets: [
                    #"{"name":"McDuck-1.2-macos.zip","browser_download_url":"https://example.com/McDuck-1.2-macos.zip"}"#
                ]),
                expectedChannel: .release
            )
        }
    }

    private func stableReleasePayload(tag: String, assets: [String]? = nil) -> Data {
        let assets = assets ?? [
            #"{"name":"McDuck.pkg","browser_download_url":"https://example.com/McDuck.pkg"}"#,
            #"{"name":"McDuck-\#(tag).pkg","browser_download_url":"https://example.com/McDuck-\#(tag).pkg"}"#
        ]
        return Data("""
        {
          "tag_name": "\(tag)",
          "name": "McDuck-\(tag)",
          "prerelease": false,
          "assets": [\(assets.joined(separator: ","))]
        }
        """.utf8)
    }

    private func snapshotLatestPayload(version: String) -> Data {
        Data("""
        {
          "tag_name": "snapshot-latest",
          "name": "McDuck snapshot (latest)",
          "prerelease": true,
          "assets": [
            {"name":"McDuck.pkg","browser_download_url":"https://example.com/snapshot/McDuck.pkg"},
            {"name":"McDuck-\(version).pkg","browser_download_url":"https://example.com/snapshot/McDuck-\(version).pkg"}
          ]
        }
        """.utf8)
    }
}
