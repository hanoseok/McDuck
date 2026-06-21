---
type: Module
title: McDuck MCP
description: Stdio MCP server exposing McDuck usage data to agents.
resource: https://github.com/hanoseok/McDuck/tree/develop/Sources/McDuckMCP
tags: [module, mcp, agents, usage-report]
timestamp: 2026-06-21T06:44:10Z
---
# Responsibility

The MCP subsystem exposes local `ccusage` data through agent-callable tools.

* `MCPRequestHandler` handles JSON-RPC/MCP lifecycle and tool calls.
* `MCPTools` defines `usage_summary`, `daily_usage`, and `model_breakdown`.
* `JSONRPC` and `JSONValue` provide protocol encoding helpers.
* `Sources/mcduck-mcp/MCPMain.swift` is the stdio executable entry point.

# Tools

| Tool | Purpose |
| --- | --- |
| `usage_summary` | Total tokens and cost over an optional date range. |
| `daily_usage` | Per-day token/cost rows over an optional date range. |
| `model_breakdown` | Per-model aggregate tokens/cost over an optional date range. |

# Dependencies

* Reuses [McDuck Core](/modules/mcduck-core.md) for usage loading and parsing.
* Distributed through [Claude Plugin](/modules/claude-plugin.md) and release assets.

# Testing

Relevant tests live in `Tests/McDuckMCPTests`.
