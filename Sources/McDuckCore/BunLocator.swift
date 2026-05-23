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
