# McDuck Work Summary - 2026-05-29

## Current Repository State

- Active branch after completion: `main`.
- Remote branch state: `main` is pushed to `origin/main`.
- Merge commit: `a49e003 merge: native menu bar app`.
- Feature branch retained: `codex/native-menu-bar-app`.
- Working tree was clean when this summary was created.

## User Goal

Build McDuck as a native macOS menu bar app. When launched, it should appear in the macOS menu bar, open a popover from the status item, and show LLM token usage from `bunx ccusage` as graphs, including a GitHub-style daily heatmap.

## Implemented Product Behavior

- Native SwiftUI macOS app.
- Menu bar entry through `MenuBarExtra("McDuck", systemImage: "chart.bar.xaxis")`.
- Window-style menu bar popover through `.menuBarExtraStyle(.window)`.
- Dockless app packaging through `LSUIElement=true`.
- Heatmap-first popover layout.
- Daily usage heatmap for the latest 12 weeks.
- Selected-day detail panel showing total tokens, cost, input/output tokens, cache tokens, and model breakdown.
- Swift Charts summary bar chart for recent daily usage.
- Liquid Glass styling through `GlassEffectContainer` and `glassEffect`, with material fallback.

## Dependency And Data Flow

- App checks for Bun before loading usage.
- Bun lookup checks `PATH`, `~/.bun/bin/bun`, `/opt/homebrew/bin/bun`, and `/usr/local/bin/bun`.
- App uses user-initiated setup only. It does not auto-install dependencies on launch.
- If Bun is missing, setup runs:

```bash
curl -fsSL https://bun.sh/install | bash
```

- If `ccusage` is not ready, setup runs `bunx` bootstrap through Bun.
- Usage data command:

```bash
bunx ccusage daily --json --breakdown
```

- `ccusage` JSON parsing supports both modern `data`/`summary` and alternate `daily`/`totals` structures.

## Architecture

- `Package.swift`: Swift package definition.
- `Sources/McDuck`: macOS app and SwiftUI UI layer.
- `Sources/McDuckCore`: testable core library for command execution, dependency checks, parsing, and heatmap data.
- `Tests/McDuckCoreTests`: parser, heatmap, and dependency tests.
- `Resources/Info.plist`: app bundle metadata with `LSUIElement=true`.
- `scripts/build-app.sh`: builds `dist/McDuck.app`.

## Important Files

- `AGENTS.html`: canonical agent guide for this repository.
- `CLAUDE.md`: short pointer telling Claude to read `AGENTS.html`.
- `README.md`: user-facing build and usage instructions.
- `docs/superpowers/specs/2026-05-24-mcduck-native-menu-bar-design.md`: design spec.
- `docs/superpowers/plans/2026-05-24-mcduck-native-menu-bar.md`: implementation plan.

## Commit History Of Main Work

- `01c1ad9 docs: design native menu bar app`
- `b80e5cf docs: plan native menu bar app`
- `6a3d70e feat: add ccusage core`
- `58e9bed feat: add native menu bar UI`
- `06b1e34 chore: package mac app`
- `318cb3a docs: add agent guide`
- `a49e003 merge: native menu bar app`

## Verification Already Performed

Before merging to main, the following passed:

```bash
swift test
swift build
scripts/build-app.sh
```

After merging to main, the following also passed:

```bash
swift test
swift build
scripts/build-app.sh
```

The app bundle was created at:

```text
dist/McDuck.app
```

## Known Operational Notes

- `dist/` is ignored and should not be committed.
- The previous automatic PR creation attempt was blocked because the GitHub connector only had access to `aston-han` repositories, while this repository is `hanoseok/McDuck`; local git push over SSH worked.
- The feature branch `codex/native-menu-bar-app` remains available locally and remotely after being merged.
- Signing, notarization, auto-update, and DMG packaging are not implemented yet.

## Recommended Next Steps

- Run the packaged app with `open dist/McDuck.app` and inspect the menu bar popover manually.
- Decide whether to delete the merged feature branch.
- Add code signing and notarization before public distribution.
- Add UI-level smoke tests or screenshot verification if the app UI grows.
