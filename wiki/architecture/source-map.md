---
type: Architecture
title: Source Map
description: Directory-level map of McDuck source code, tests, scripts, and documentation.
resource: https://github.com/hanoseok/McDuck/tree/develop
tags: [architecture, source-map, repository]
timestamp: 2026-06-21T06:44:10Z
---
# Source Directories

| Path | Role | Primary Concepts |
| --- | --- | --- |
| `Sources/McDuck` | macOS app target | [McDuck App](/modules/mcduck-app.md) |
| `Sources/McDuckCore` | testable domain/core logic | [McDuck Core](/modules/mcduck-core.md) |
| `Sources/McDuckMCP` | MCP request handling and tool aggregation | [McDuck MCP](/modules/mcduck-mcp.md) |
| `Sources/mcduck-mcp` | MCP executable entry point | [McDuck MCP](/modules/mcduck-mcp.md) |
| `Tests/McDuckTests` | app-level unit tests with fakes | [McDuck App](/modules/mcduck-app.md) |
| `Tests/McDuckCoreTests` | parser, dependency, command, heatmap tests | [McDuck Core](/modules/mcduck-core.md) |
| `Tests/McDuckMCPTests` | JSON-RPC and MCP handler/tool tests | [McDuck MCP](/modules/mcduck-mcp.md) |
| `plugin/` | Claude Code plugin bundle | [Claude Plugin](/modules/claude-plugin.md) |
| `skills/` | Repository-owned Codex workflow skills with thin installed pointers | [Codex Skills](/modules/codex-skills.md) |
| `scripts/` | app build and installer scripts | [Build, Test, Release Runbook](/runbooks/build-test-release.md) |
| `.github/workflows/` | CI, release, snapshot, cut bridge | [Release Pipeline](/architecture/release-pipeline.md) |
| `docs/` | legacy/planning/build docs | [Build, Test, Release Runbook](/runbooks/build-test-release.md) |
| `wiki/` | OKF-style project knowledge bundle | [OKF Wiki Decision](/decisions/0001-okf-wiki.md) |

# Update Rule

When a new persistent subsystem is added, create or update a module concept under `/modules/` and link it from this source map.
