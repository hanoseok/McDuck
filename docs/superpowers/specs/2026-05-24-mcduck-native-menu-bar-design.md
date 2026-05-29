# McDuck Native Menu Bar Design

## Goal

McDuck is a native macOS menu bar app that visualizes local LLM token usage from `ccusage`. It runs without a Dock icon, shows a persistent menu bar icon, and opens a compact popover focused on daily usage.

## Platform And Technology

- Build as a native SwiftUI macOS app.
- Use `MenuBarExtra` with `.menuBarExtraStyle(.window)` for the status bar entry and popover-style content.
- Set `LSUIElement` to `true` so the app behaves as a menu bar utility instead of a Dock app.
- Use Swift Charts where available for simple summary bars, and custom SwiftUI grid cells for the GitHub-style daily heatmap.
- Use Swift concurrency for command execution and refresh tasks.
- Apply Liquid Glass on macOS SDKs that support it with `glassEffect` and `GlassEffectContainer`; provide a material-based fallback so the project still builds on the installed local SDK if Liquid Glass symbols are unavailable.

Apple documentation checked during design:

- `MenuBarExtra` is the SwiftUI scene for persistent controls in the system menu bar, with `.window` style for data-rich popover-like content.
- SwiftUI Liquid Glass can be applied to custom views with `glassEffect(_:in:)`, and grouped with `GlassEffectContainer` for performance and morphing behavior.

## First-Run And Installation Flow

The app checks for `bun` and verifies that `bunx ccusage --version` can run.

If dependencies are ready, McDuck loads usage immediately.

If dependencies are missing, the popover shows a setup state:

- `bun` missing: explain that Bun is required and show an Install button.
- `ccusage` unavailable through `bunx`: show an Install button that runs `bunx ccusage --version` to let Bun download and cache the package.
- Installation is user initiated. McDuck does not install automatically on launch.
- Installation progress, stdout/stderr summaries, and failure recovery are shown in the popover.

Because `bunx` can run package binaries without a separate global install, McDuck does not manage a global `ccusage` binary. This keeps package updates simple and avoids writing into global npm-style paths.

## Usage Data Flow

McDuck runs:

```bash
bunx ccusage daily --json --breakdown
```

The command is executed through a small process runner that:

- Locates `bun` in common interactive-shell locations including `/opt/homebrew/bin`, `/usr/local/bin`, and `~/.bun/bin`.
- Uses a deterministic environment and timeout.
- Captures stdout, stderr, exit status, and decoding errors.

The JSON parser accepts the modern `ccusage` daily structure:

- `type`
- `data`
- `summary`
- per-day fields such as `date`, `inputTokens`, `outputTokens`, `cacheCreationTokens`, `cacheReadTokens`, `totalTokens`, `costUSD`, `models`, and `breakdown`

The parser also tolerates the alternate structure documented by ccusage where daily rows may appear under `daily` and totals under `totals`.

## Popover UX

The selected direction is Heatmap First.

The popover opens to:

- Header with app name, current refresh status, and refresh button.
- Main GitHub-style heatmap covering recent daily usage.
- Selected-day detail panel with total tokens, input/output/cache tokens, estimated cost, and models used.
- Small model breakdown list for the selected day when `--breakdown` data exists.
- Footer actions for Refresh, Setup, and Quit.

The heatmap uses token intensity, not cost, as the primary color scale. Empty days render as a low-emphasis cell. Selecting a day updates the detail panel.

## Error Handling

McDuck distinguishes these states:

- Missing Bun.
- `bunx ccusage` bootstrap failure.
- `ccusage` exits with a non-zero status.
- JSON cannot be decoded.
- No usage data found.

Errors are recoverable from the popover with Retry or Setup actions. Raw terminal noise is summarized, not dumped into the UI.

## Refresh Behavior

The app refreshes when:

- The popover appears.
- The user clicks Refresh.
- A setup step completes successfully.

Automatic background polling is not part of the first version. It can be added later once command cost and user expectations are clearer.

## Testing Strategy

The first implementation uses focused unit tests before production code:

- Parse modern `ccusage daily --json --breakdown` output.
- Parse alternate `daily`/`totals` output.
- Convert daily usage into heatmap cells with stable date ordering and intensity buckets.
- Detect dependency status from fake command-runner results.
- Surface command failures as typed user-facing states.

The SwiftUI popover is verified by building the app target and, where practical, running a lightweight local smoke test of the parsing and view-model code.

## Packaging

The repository will include a Swift Package layout that can build a macOS `.app` bundle through a small packaging script. This avoids hand-maintaining a large Xcode project while still producing a native app artifact.

The generated app bundle includes:

- `Contents/Info.plist` with `LSUIElement=true`
- the compiled executable
- minimal app metadata

Future distribution work can add signing, notarization, and a DMG installer. The first milestone produces a locally runnable `.app`.
