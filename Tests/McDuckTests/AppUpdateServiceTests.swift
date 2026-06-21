import Foundation
import McDuckCore
import Testing
@testable import McDuck

@Suite("app update service")
struct AppUpdateServiceTests {
    @Test("release builds fetch the stable latest release endpoint")
    func releaseEndpoint() async throws {
        let http = CapturingHTTPClient(data: stableReleasePayload(tag: "1.2"))
        let service = AppUpdateService(
            currentVersionProvider: { "1.1" },
            httpClient: http,
            packageOpener: RecordingPackageOpener(),
            fileClient: FileManagerAppUpdateFileClient()
        )

        let result = await service.checkForUpdate()

        if case .available = result {} else { Issue.record("expected available, got \(result)") }
        #expect(http.dataURLs.map(\.absoluteString) == [
            "https://api.github.com/repos/hanoseok/McDuck/releases/latest"
        ])
    }

    @Test("snapshot builds fetch snapshot-latest and open the downloaded package")
    func snapshotEndpointAndInstall() async throws {
        let downloaded = try makeDownloadedPackage()
        let release = try AppUpdateRelease.githubRelease(
            data: snapshotLatestPayload(version: "1.2.1-SNAPSHOT"),
            expectedChannel: .snapshot
        )
        let http = CapturingHTTPClient(
            data: snapshotLatestPayload(version: "1.2.1-SNAPSHOT"),
            downloadedFile: downloaded
        )
        let opener = RecordingPackageOpener()
        let service = AppUpdateService(
            currentVersionProvider: { "1.2.0-SNAPSHOT" },
            httpClient: http,
            packageOpener: opener,
            fileClient: FileManagerAppUpdateFileClient()
        )

        let check = await service.checkForUpdate()
        let install = await service.installUpdate(release)

        if case .available = check {} else { Issue.record("expected available, got \(check)") }
        if case .openedInstaller = install {} else { Issue.record("expected openedInstaller, got \(install)") }
        #expect(http.dataURLs.map(\.absoluteString) == [
            "https://api.github.com/repos/hanoseok/McDuck/releases/tags/snapshot-latest"
        ])
        #expect(http.downloadURLs == [release.packageAsset.downloadURL])
        #expect(opener.openedPackageURLs.last?.lastPathComponent == "McDuck-1.2.1-SNAPSHOT.pkg")
    }

    private func stableReleasePayload(tag: String) -> Data {
        Data("""
        {
          "tag_name": "\(tag)",
          "name": "McDuck-\(tag)",
          "prerelease": false,
          "assets": [
            {"name":"McDuck.pkg","browser_download_url":"https://example.com/McDuck.pkg"}
          ]
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

    private func makeDownloadedPackage() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("McDuckTest-\(UUID().uuidString).pkg")
        try Data("pkg".utf8).write(to: url)
        return url
    }
}

private final class CapturingHTTPClient: AppUpdateHTTPClient, @unchecked Sendable {
    let data: Data
    let downloadedFile: URL?
    private(set) var dataURLs: [URL] = []
    private(set) var downloadURLs: [URL] = []

    init(data: Data, downloadedFile: URL? = nil) {
        self.data = data
        self.downloadedFile = downloadedFile
    }

    func data(from url: URL) async throws -> Data {
        dataURLs.append(url)
        return data
    }

    func download(from url: URL) async throws -> URL {
        downloadURLs.append(url)
        return downloadedFile ?? url
    }
}

private final class RecordingPackageOpener: AppUpdatePackageOpening, @unchecked Sendable {
    private(set) var openedPackageURLs: [URL] = []

    func openPackage(at url: URL) async -> Bool {
        openedPackageURLs.append(url)
        return true
    }
}
