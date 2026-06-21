---
type: Module
title: Claude Plugin
description: Bundled Claude Code plugin marketplace, launcher, and usage-report skill for McDuck MCP.
resource: https://github.com/hanoseok/McDuck/tree/develop/plugin
tags: [module, claude-code, plugin, mcp, skill]
timestamp: 2026-06-21T06:44:10Z
---
# Responsibility

`plugin/` packages McDuck's MCP server integration for Claude Code.

* `plugin/.claude-plugin/plugin.json` declares the marketplace plugin.
* `plugin/bin/mcduck-mcp` launches a prebuilt MCP binary when available, or builds from the bundled Swift package as fallback.
* `plugin/skills/usage-report/SKILL.md` teaches agents how to answer usage/cost questions using McDuck MCP tools.

# App Integration

The installed McDuck app bundles this marketplace under app resources so users can register it locally from settings without relying on a network fetch.

# Related Concepts

* [McDuck MCP](/modules/mcduck-mcp.md)
* [McDuck App](/modules/mcduck-app.md)
* [Release Pipeline](/architecture/release-pipeline.md)
