import Foundation
import Testing
@testable import McDuckCore

/// Covers `BunLocator.augmentedPATH` (a pure function) and `findBun`'s
/// filesystem probing via temporary executables.
@Suite("bun locator")
struct BunLocatorTests {
    // MARK: - augmentedPATH

    @Test("augmentedPATH puts bun's directory first and appends common locations")
    func augmentedPATHOrdering() {
        let path = BunLocator.augmentedPATH(
            bunPath: "/custom/tools/bun",
            home: URL(fileURLWithPath: "/Users/test"),
            basePATH: "/usr/bin:/bin"
        )

        #expect(path.split(separator: ":").map(String.init) == [
            "/custom/tools/bun",
            "/Users/test/.bun/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ])
    }

    @Test("augmentedPATH de-duplicates entries already present in the base PATH")
    func augmentedPATHDeduplicates() {
        let path = BunLocator.augmentedPATH(
            bunPath: "/opt/homebrew/bin/bun",
            home: URL(fileURLWithPath: "/Users/test"),
            basePATH: "/opt/homebrew/bin:/usr/local/bin"
        )

        let entries = path.split(separator: ":").map(String.init)
        #expect(entries.first == "/opt/homebrew/bin")
        #expect(entries.filter { $0 == "/opt/homebrew/bin" }.count == 1)
        #expect(entries.filter { $0 == "/usr/local/bin" }.count == 1)
    }

    @Test("augmentedPATH drops empty path segments")
    func augmentedPATHDropsEmptySegments() {
        let path = BunLocator.augmentedPATH(
            bunPath: "/custom/bun",
            home: URL(fileURLWithPath: "/Users/test"),
            basePATH: "::/extra:"
        )

        let entries = path.split(separator: ":").map(String.init)
        #expect(!entries.contains(""))
        #expect(entries.contains("/extra"))
    }

    // MARK: - findBun

    @Test("findBun returns an executable bun found on the PATH")
    func findBunOnPath() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let bun = try dir.makeExecutable(named: "bun")

        let locator = BunLocator(
            environment: ["PATH": dir.path],
            homeDirectory: URL(fileURLWithPath: "/nonexistent-home")
        )

        #expect(locator.findBun() == bun)
    }

    @Test("findBun falls back to ~/.bun/bin/bun when PATH has none")
    func findBunInHomeFallback() throws {
        let home = try TempDir()
        defer { home.cleanup() }
        let bunDir = try home.makeSubdirectory(".bun/bin")
        let bun = try bunDir.makeExecutable(named: "bun")

        let locator = BunLocator(
            environment: ["PATH": ""],
            homeDirectory: URL(fileURLWithPath: home.path)
        )

        #expect(locator.findBun() == bun)
    }

    @Test("findBun prefers a PATH hit over the home fallback")
    func findBunPrefersPath() throws {
        let pathDir = try TempDir()
        defer { pathDir.cleanup() }
        let pathBun = try pathDir.makeExecutable(named: "bun")

        let home = try TempDir()
        defer { home.cleanup() }
        let bunDir = try home.makeSubdirectory(".bun/bin")
        _ = try bunDir.makeExecutable(named: "bun")

        let locator = BunLocator(
            environment: ["PATH": pathDir.path],
            homeDirectory: URL(fileURLWithPath: home.path)
        )

        #expect(locator.findBun() == pathBun)
    }
}

/// A self-cleaning temporary directory helper for filesystem-backed tests.
private struct TempDir {
    let url: URL

    var path: String { url.path }

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcduck-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private init(url: URL) {
        self.url = url
    }

    func makeSubdirectory(_ relativePath: String) throws -> TempDir {
        let sub = url.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        return TempDir(url: sub)
    }

    /// Creates an executable file and returns its absolute path.
    func makeExecutable(named name: String) throws -> String {
        let file = url.appendingPathComponent(name, isDirectory: false)
        try Data("#!/bin/sh\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        return file.path
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}
