import Foundation

public protocol BunLocating: Sendable {
    func findBun() -> String?
}

public struct StaticBunLocator: BunLocating {
    private let path: String?

    public init(path: String?) {
        self.path = path
    }

    public func findBun() -> String? {
        path
    }
}

public extension BunLocator {
    /// A PATH that includes bun's directory and common install locations.
    /// GUI apps launched from Finder/the installer inherit a minimal PATH
    /// (`/usr/bin:/bin:...`), so bun (and the tools it shells out to) may not be
    /// found when running `bun x ccusage`. Pass this as the subprocess PATH.
    static func augmentedPATH(
        bunPath: String,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        basePATH: String = ProcessInfo.processInfo.environment["PATH"] ?? ""
    ) -> String {
        let bunDirectory = (bunPath as NSString).deletingLastPathComponent
        let preferred = [
            bunDirectory,
            home.appending(path: ".bun/bin").path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let existing = basePATH.split(separator: ":").map(String.init)

        var seen = Set<String>()
        let merged = (preferred + existing).filter { !$0.isEmpty && seen.insert($0).inserted }
        return merged.joined(separator: ":")
    }
}

public struct BunLocator: BunLocating {
    private let environment: [String: String]
    private let homeDirectory: URL

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.environment = environment
        self.homeDirectory = homeDirectory
    }

    public func findBun() -> String? {
        let pathEntries = environment["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)

        let candidates = pathEntries.map { "\($0)/bun" } + [
            homeDirectory.appending(path: ".bun/bin/bun").path,
            "/opt/homebrew/bin/bun",
            "/usr/local/bin/bun"
        ]

        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }
}
