---
type: Architecture
title: System Overview
description: High-level runtime architecture and data flow for McDuck.
resource: https://github.com/hanoseok/McDuck/tree/develop
tags: [architecture, runtime, data-flow, mcduck]
timestamp: 2026-06-21T06:44:10Z
---
# Runtime Shape

McDuck is a local-first macOS menu bar application. The app does not own a remote backend; it reads local usage data through `bunx ccusage` and renders it in a SwiftUI popover.

# Components

| Component | Source | Responsibility |
| --- | --- | --- |
| Menu bar app | [McDuck App](/modules/mcduck-app.md) | SwiftUI popover, settings, menu bar label, setup flow |
| Core usage layer | [McDuck Core](/modules/mcduck-core.md) | Bun discovery, command execution, ccusage parsing, heatmap building |
| MCP server | [McDuck MCP](/modules/mcduck-mcp.md) | Stdio MCP tools for usage summary, daily usage, and model breakdown |
| Claude plugin | [Claude Plugin](/modules/claude-plugin.md) | Bundled marketplace, skill, launcher, install/uninstall integration |
| CI/release | [Release Pipeline](/architecture/release-pipeline.md) | macOS GitHub Actions builds, packages, and publishes releases |

# Data Flow

1. `UsageStore` checks dependencies through `CcusageClient`.
2. `CcusageClient` asks `DependencyManager` for Bun and `ccusage` readiness.
3. When ready, McDuck runs `bun x ccusage daily --json --breakdown`.
4. `CcusageParser` decodes tolerant daily usage and model breakdown data.
5. `UsageStore` exposes dashboard-ready state to `McDuckPopover`, `HeatmapGrid`, `UsageDetailView`, and `MenuBarLabel`.
6. In parallel, activity time is fetched through `bun x ccusage blocks --json` and folded into per-day durations.
7. The MCP server reuses the same core report path and exposes aggregated tools to agents.

# Operating Constraints

* Local development and tests require macOS with Swift 6.2+/Xcode 26+.
* This Linux agent session cannot build SwiftUI/macOS targets directly.
* GitHub Actions macOS runners are the authoritative verification and packaging environment.

# Related Concepts

* [McDuck Core](/modules/mcduck-core.md)
* [McDuck App](/modules/mcduck-app.md)
* [Release Pipeline](/architecture/release-pipeline.md)
