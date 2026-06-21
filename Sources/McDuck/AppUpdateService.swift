import AppKit
import Foundation
import McDuckCore

enum AppUpdateCheckResult: Equatable, Sendable {
    case upToDate(current: InstalledAppVersion, latest: AppUpdateRelease)
    case available(current: InstalledAppVersion, latest: AppUpdateRelease)
    case failed(String)
}

enum AppUpdateInstallResult: Equatable, Sendable {
    case openedInstaller(URL)
    case failed(String)
}

protocol AppUpdating: Sendable {
    func currentInstalledVersion() -> InstalledAppVersion?
    func checkForUpdate() async -> AppUpdateCheckResult
    func installUpdate(_ release: AppUpdateRelease) async -> AppUpdateInstallResult
}

protocol AppUpdateHTTPClient: Sendable {
    func data(from url: URL) async throws -> Data
    func download(from url: URL) async throws -> URL
}

protocol AppUpdatePackageOpening: Sendable {
    func openPackage(at url: URL) async -> Bool
}

protocol AppUpdateFileManaging: Sendable {
    var temporaryDirectory: URL { get }
    func fileExists(atPath path: String) -> Bool
    func removeItem(at url: URL) throws
    func copyItem(at source: URL, to destination: URL) throws
}

struct URLSessionAppUpdateHTTPClient: AppUpdateHTTPClient {
    func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response)
        return data
    }

    func download(from url: URL) async throws -> URL {
        let (fileURL, response) = try await URLSession.shared.download(from: url)
        try validate(response: response)
        return fileURL
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw AppUpdateServiceError.badServerResponse
        }
    }
}

struct WorkspacePackageOpener: AppUpdatePackageOpening {
    func openPackage(at url: URL) async -> Bool {
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }
}

struct FileManagerAppUpdateFileClient: AppUpdateFileManaging {
    var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func copyItem(at source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }
}

enum AppUpdateServiceError: Error, LocalizedError {
    case missingCurrentVersion
    case badServerResponse
    case installerDidNotOpen

    var errorDescription: String? {
        switch self {
        case .missingCurrentVersion:
            "Cannot determine the current McDuck version."
        case .badServerResponse:
            "GitHub returned an unexpected response."
        case .installerDidNotOpen:
            "The downloaded installer package could not be opened."
        }
    }
}

struct AppUpdateService: AppUpdating {
    private let currentVersionProvider: @Sendable () -> String?
    private let httpClient: any AppUpdateHTTPClient
    private let packageOpener: any AppUpdatePackageOpening
    private let fileClient: any AppUpdateFileManaging

    init(
        currentVersionProvider: @escaping @Sendable () -> String? = {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        },
        httpClient: any AppUpdateHTTPClient = URLSessionAppUpdateHTTPClient(),
        packageOpener: any AppUpdatePackageOpening = WorkspacePackageOpener(),
        fileClient: any AppUpdateFileManaging = FileManagerAppUpdateFileClient()
    ) {
        self.currentVersionProvider = currentVersionProvider
        self.httpClient = httpClient
        self.packageOpener = packageOpener
        self.fileClient = fileClient
    }

    func currentInstalledVersion() -> InstalledAppVersion? {
        guard let raw = currentVersionProvider() else {
            return nil
        }
        return try? InstalledAppVersion(raw)
    }

    func checkForUpdate() async -> AppUpdateCheckResult {
        guard let current = currentInstalledVersion() else {
            return .failed(AppUpdateServiceError.missingCurrentVersion.localizedDescription)
        }

        do {
            let data = try await httpClient.data(from: releaseMetadataURL(for: current.channel))
            let latest = try AppUpdateRelease.githubRelease(data: data, expectedChannel: current.channel)
            switch try AppUpdateAvailability.evaluate(current: current, latest: latest) {
            case .available(let current, let latest):
                return .available(current: current, latest: latest)
            case .upToDate(let current, let latest):
                return .upToDate(current: current, latest: latest)
            }
        } catch let error as LocalizedError {
            return .failed(error.localizedDescription)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func installUpdate(_ release: AppUpdateRelease) async -> AppUpdateInstallResult {
        do {
            let downloaded = try await httpClient.download(from: release.packageAsset.downloadURL)
            let destination = fileClient.temporaryDirectory
                .appendingPathComponent("McDuck-\(release.version.description).pkg")
            if fileClient.fileExists(atPath: destination.path) {
                try fileClient.removeItem(at: destination)
            }
            try fileClient.copyItem(at: downloaded, to: destination)

            guard await packageOpener.openPackage(at: destination) else {
                throw AppUpdateServiceError.installerDidNotOpen
            }
            return .openedInstaller(destination)
        } catch let error as LocalizedError {
            return .failed(error.localizedDescription)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func releaseMetadataURL(for channel: AppUpdateChannel) -> URL {
        switch channel {
        case .release:
            URL(string: "https://api.github.com/repos/hanoseok/McDuck/releases/latest")!
        case .snapshot:
            URL(string: "https://api.github.com/repos/hanoseok/McDuck/releases/tags/snapshot-latest")!
        }
    }
}
