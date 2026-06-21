import Foundation

public enum AppUpdateChannel: String, Equatable, Sendable {
    case release
    case snapshot

    public var title: String {
        switch self {
        case .release: "Release"
        case .snapshot: "Snapshot"
        }
    }
}

public enum AppUpdateError: Error, Equatable, LocalizedError, Sendable {
    case invalidVersion(String)
    case invalidReleasePayload
    case missingPackageAsset
    case channelMismatch

    public var errorDescription: String? {
        switch self {
        case .invalidVersion(let value):
            "Invalid app version: \(value)"
        case .invalidReleasePayload:
            "The release metadata could not be read."
        case .missingPackageAsset:
            "The release does not include McDuck.pkg."
        case .channelMismatch:
            "The update channel does not match this build."
        }
    }
}

public struct AppVersion: Comparable, CustomStringConvertible, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let includesPatch: Bool
    public let isSnapshot: Bool

    public init(_ rawValue: String) throws {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") {
            value.removeFirst()
        }

        let snapshotSuffix = "-SNAPSHOT"
        isSnapshot = value.hasSuffix(snapshotSuffix)
        if isSnapshot {
            value.removeLast(snapshotSuffix.count)
        }

        let parts = value.split(separator: ".")
        guard parts.count == 2 || parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]) else {
            throw AppUpdateError.invalidVersion(rawValue)
        }

        let patch: Int
        if parts.count == 3 {
            guard let parsedPatch = Int(parts[2]) else {
                throw AppUpdateError.invalidVersion(rawValue)
            }
            patch = parsedPatch
        } else {
            guard !isSnapshot else {
                throw AppUpdateError.invalidVersion(rawValue)
            }
            patch = 0
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.includesPatch = parts.count == 3
    }

    public var description: String {
        let base = includesPatch ? "\(major).\(minor).\(patch)" : "\(major).\(minor)"
        return isSnapshot ? "\(base)-SNAPSHOT" : base
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        [lhs.major, lhs.minor, lhs.patch].lexicographicallyPrecedes([rhs.major, rhs.minor, rhs.patch])
    }
}

public struct InstalledAppVersion: Equatable, CustomStringConvertible, Sendable {
    public let rawValue: String
    public let version: AppVersion
    public let channel: AppUpdateChannel

    public init(_ rawValue: String) throws {
        let version = try AppVersion(rawValue)
        self.rawValue = rawValue
        self.version = version
        self.channel = version.isSnapshot ? .snapshot : .release
    }

    public var description: String {
        version.description
    }
}

public struct AppUpdateAsset: Equatable, Sendable {
    public let name: String
    public let downloadURL: URL

    public init(name: String, downloadURL: URL) {
        self.name = name
        self.downloadURL = downloadURL
    }
}

public struct AppUpdateRelease: Equatable, Sendable {
    public let tagName: String
    public let name: String
    public let version: AppVersion
    public let channel: AppUpdateChannel
    public let packageAsset: AppUpdateAsset

    public static func githubRelease(
        data: Data,
        expectedChannel: AppUpdateChannel
    ) throws -> AppUpdateRelease {
        let decoder = JSONDecoder()
        let payload: GitHubReleasePayload
        do {
            payload = try decoder.decode(GitHubReleasePayload.self, from: data)
        } catch {
            throw AppUpdateError.invalidReleasePayload
        }

        switch expectedChannel {
        case .release:
            guard payload.prerelease != true else {
                throw AppUpdateError.channelMismatch
            }
            let installed = try InstalledAppVersion(payload.tagName)
            guard installed.channel == .release else {
                throw AppUpdateError.channelMismatch
            }
            let asset = try packageAsset(in: payload.assets, preferredNames: [
                "McDuck.pkg",
                "McDuck-\(installed.version.description).pkg"
            ])
            return AppUpdateRelease(
                tagName: payload.tagName,
                name: payload.name,
                version: installed.version,
                channel: .release,
                packageAsset: asset
            )

        case .snapshot:
            guard payload.prerelease != false else {
                throw AppUpdateError.channelMismatch
            }
            let installed = try snapshotVersion(from: payload)
            let asset = try packageAsset(in: payload.assets, preferredNames: [
                "McDuck.pkg",
                "McDuck-\(installed.version.description).pkg"
            ])
            return AppUpdateRelease(
                tagName: payload.tagName,
                name: payload.name,
                version: installed.version,
                channel: .snapshot,
                packageAsset: asset
            )
        }
    }

    private static func snapshotVersion(from payload: GitHubReleasePayload) throws -> InstalledAppVersion {
        if let version = try? InstalledAppVersion(payload.tagName), version.channel == .snapshot {
            return version
        }

        for asset in payload.assets {
            guard asset.name.hasPrefix("McDuck-"),
                  asset.name.hasSuffix(".pkg"),
                  asset.name != "McDuck.pkg" else {
                continue
            }
            let start = asset.name.index(asset.name.startIndex, offsetBy: "McDuck-".count)
            let end = asset.name.index(asset.name.endIndex, offsetBy: -".pkg".count)
            let candidate = String(asset.name[start..<end])
            if let version = try? InstalledAppVersion(candidate), version.channel == .snapshot {
                return version
            }
        }

        throw AppUpdateError.channelMismatch
    }

    private static func packageAsset(
        in assets: [GitHubReleaseAssetPayload],
        preferredNames: [String]
    ) throws -> AppUpdateAsset {
        for name in preferredNames {
            if let asset = assets.first(where: { $0.name == name }), let url = URL(string: asset.downloadURL) {
                return AppUpdateAsset(name: asset.name, downloadURL: url)
            }
        }
        throw AppUpdateError.missingPackageAsset
    }
}

public enum AppUpdateAvailability: Equatable, Sendable {
    case upToDate(current: InstalledAppVersion, latest: AppUpdateRelease)
    case available(current: InstalledAppVersion, latest: AppUpdateRelease)

    public static func evaluate(
        current: InstalledAppVersion,
        latest: AppUpdateRelease
    ) throws -> AppUpdateAvailability {
        guard current.channel == latest.channel else {
            throw AppUpdateError.channelMismatch
        }

        if current.version < latest.version {
            return .available(current: current, latest: latest)
        }
        return .upToDate(current: current, latest: latest)
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let name: String
    let prerelease: Bool?
    let assets: [GitHubReleaseAssetPayload]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        tagName = try container.decodeFirst(String.self, forKeys: ["tag_name", "tagName"])
        name = (try? container.decodeFirst(String.self, forKeys: ["name"])) ?? tagName
        prerelease = try? container.decodeFirst(Bool.self, forKeys: ["prerelease", "isPrerelease"])
        assets = (try? container.decodeFirst([GitHubReleaseAssetPayload].self, forKeys: ["assets"])) ?? []
    }
}

private struct GitHubReleaseAssetPayload: Decodable {
    let name: String
    let downloadURL: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        name = try container.decodeFirst(String.self, forKeys: ["name"])
        downloadURL = try container.decodeFirst(
            String.self,
            forKeys: ["browser_download_url", "browserDownloadUrl", "url"]
        )
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKey {
    func decodeFirst<T: Decodable>(_ type: T.Type, forKeys keys: [String]) throws -> T {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key), contains(codingKey) else {
                continue
            }
            return try decode(type, forKey: codingKey)
        }
        throw DecodingError.keyNotFound(
            DynamicCodingKey(stringValue: keys.first ?? "")!,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing keys: \(keys.joined(separator: ", "))")
        )
    }
}
