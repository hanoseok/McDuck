---
type: Module
title: McDuck App
description: SwiftUI macOS menu bar target that renders usage data, settings, setup, and plugin controls.
resource: https://github.com/hanoseok/McDuck/tree/develop/Sources/McDuck
tags: [module, app, swiftui, menu-bar, settings]
timestamp: 2026-06-21T14:05:54Z
---
# Responsibility

`Sources/McDuck` contains the macOS application surface:

* `McDuckApp` wires `MenuBarExtra`, `UsageStore`, and `SettingsStore`.
* `McDuckPopover` renders dashboard, controls, chart, heatmap, detail view, footer, and settings popover.
* `UsageStore` is the main observable state machine for dependency checks, usage loading, auto-refresh, and activity loading.
* `SettingsStore` persists menu bar settings, login item state, Claude plugin install state, and app update-check state. It starts an automatic release-channel check at launch and repeats it every 10 minutes while the app is running.
* `PluginInstaller` integrates the bundled Claude Code plugin via CLI or `~/.claude/settings.json` fallback.
* `AppUpdateService` checks the GitHub release channel for the installed build and opens the downloaded `.pkg` with macOS Installer.
* `SetupView`, `SettingsView`, `MenuBarLabel`, `HeatmapGrid`, and `UsageDetailView` provide focused UI pieces. `SettingsView` keeps preferences, version/update controls, and the Quit action; its Version action is right-aligned and switches from Check for Updates to a blue Update install button when a release is available. The main popover footer keeps the ccusage updated time plus an icon-only usage reload action on the left, version on the right, and only exposes a blue Update action when an update is available.

# Dependencies

* Reads usage through [McDuck Core](/modules/mcduck-core.md).
* Uses [McDuck Core](/modules/mcduck-core.md) update models to keep Release builds on `releases/latest` and Snapshot builds on `snapshot-latest`.
* Installs and reports plugin state for [Claude Plugin](/modules/claude-plugin.md).
* Is built and packaged by [Release Pipeline](/architecture/release-pipeline.md).

# Testing

Relevant tests live in `Tests/McDuckTests`, including plugin installer, settings store, app update service, menu bar usage behavior, and source layout guards for Settings/main footer controls.
