# McDuck

McDuck is a native macOS menu bar app for viewing local LLM token usage from [`ccusage`](https://github.com/ryoppippi/ccusage).

It runs as a menu bar utility, opens a SwiftUI popover from the status bar icon, and shows daily token usage in a GitHub-style heatmap. It uses SwiftUI `MenuBarExtra`, Swift Charts, and Liquid Glass.

## Requirements

- macOS 15 (Sequoia) or later — Liquid Glass is used on macOS 26+, and falls back to a material on earlier versions
- Xcode 26 or later (Swift 6.2+ toolchain)
- Bun, installed by McDuck setup when the user presses Install
- `ccusage`, bootstrapped through `bunx ccusage`

McDuck does not install dependencies automatically on launch. If Bun or `ccusage` is missing, the popover shows a setup screen and waits for the user to press Install.

## Build And Test

Run unit tests:

```bash
swift test
```

Build the executable:

```bash
swift build
```

Build a local `.app` bundle:

```bash
scripts/build-app.sh
```

The bundle is written to:

```text
dist/McDuck.app
```

Run it locally:

```bash
open dist/McDuck.app
```

## Install (released builds)

Install the latest release with one command (no `xattr` / System Settings — just the admin password):

```bash
# latest
curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/install.sh | bash

# a specific version (pass the tag)
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/v0.0.20/install.sh | bash -s -- v0.0.20
```

Or download `McDuck-<tag>.pkg` from the [Releases](https://github.com/hanoseok/McDuck/releases) page and double-click it.

## Releases And Build Pipeline

Releases are built on a macOS GitHub Actions runner. `develop` publishes auto-incrementing snapshot prereleases (`1.0.0-SNAPSHOT`, `1.0.1-SNAPSHOT`, …) for the current `MAJOR.MINOR` line held in `RELEASE_VERSION`; merging `develop` → `main` publishes the official moving release `McDuck-<MAJOR.MINOR>` (e.g. `McDuck-1.0`) with a `.pkg`, a `.zip`, an installer script, and checksums. Bump `RELEASE_VERSION`'s MINOR (e.g. `1.0` → `1.1`) to start the next cycle.

See **[docs/BUILD.md](docs/BUILD.md)** for the full build, versioning, release, install, and signing/notarization guide.

## How Usage Loading Works

McDuck checks for Bun in common locations including `~/.bun/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`.

When ready, it runs:

```bash
bunx ccusage daily --json --breakdown
```

The app parses the JSON output, builds a 12-week daily heatmap, and shows the selected day's token, cost, cache, and model breakdown.

## Notes

- `LSUIElement=true` is set in `Resources/Info.plist`, so the packaged app behaves as a menu bar utility without a Dock icon.
- Signing, notarization, and DMG generation are intentionally outside the first local build milestone.
