---
type: Module
title: McDuck Core
description: Testable Swift core for Bun discovery, ccusage execution, parsing, dependency checks, update checks, and heatmap construction.
resource: https://github.com/hanoseok/McDuck/tree/develop/Sources/McDuckCore
tags: [module, core, ccusage, parser, heatmap, dependency, update]
timestamp: 2026-06-21T06:44:10Z
---
# Responsibility

`Sources/McDuckCore` is the platform-independent core layer used by both the app and MCP server.

| File | Responsibility |
| --- | --- |
| `BunLocator.swift` | Finds Bun in GUI-safe locations and builds an augmented PATH. |
| `CommandRunner.swift` | Runs external commands with stdout/stderr capture and timeout handling. |
| `DependencyManager.swift` | Checks Bun/ccusage availability and bootstraps ccusage. |
| `CcusageClient.swift` | Calls `ccusage daily --json --breakdown` and `ccusage blocks --json`. |
| `CcusageParser.swift` | Tolerantly parses daily usage, model breakdowns, totals, and active blocks. |
| `HeatmapBuilder.swift` | Builds rolling/year heatmap cells. |
| `Models.swift` | Shared usage report/value models. |
| `AppUpdate.swift` | Parses app versions and GitHub release payloads, separates Release/Snapshot channels, and evaluates update availability. |

# Current Note

The latest `develop` baseline includes `CommandRunner` pipe-draining improvements so large command output does not block while the process is still running.

# Testing

Relevant tests live in `Tests/McDuckCoreTests`.

# Related Concepts

* [System Overview](/architecture/system-overview.md)
* [McDuck MCP](/modules/mcduck-mcp.md)
