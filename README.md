# McDuck

McDuck is a native macOS menu bar app for viewing local LLM token usage from [`ccusage`](https://github.com/ryoppippi/ccusage).

It runs as a menu bar utility, opens a SwiftUI popover from the status bar icon, and shows daily token usage in a GitHub-style heatmap. The first version targets the current macOS 26 SDK and uses SwiftUI `MenuBarExtra`, Swift Charts, and Liquid Glass.

## Requirements

- macOS 26 or later
- Xcode 26.5 or later
- Swift 6.3 or later
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
curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/remote-install.sh | bash
```

Or download `McDuck-<tag>.pkg` from the [Releases](https://github.com/hanoseok/McDuck/releases) page and double-click it.

## Releases And Build Pipeline

Releases are built on a macOS GitHub Actions runner. Bump `RELEASE_VERSION` (e.g. `v1.2.0`) and push to the working branch to trigger a versioned GitHub Release with a `.pkg`, a `.zip`, an installer script, and checksums.

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
