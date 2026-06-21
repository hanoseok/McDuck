---
type: Project
title: McDuck
description: Native macOS menu bar app for viewing local LLM token usage from ccusage.
resource: https://github.com/hanoseok/McDuck
tags: [mcduck, macos, swift, ccusage, menu-bar, mcp]
timestamp: 2026-06-21T06:44:10Z
---
# Purpose

McDuck은 `bunx ccusage` 출력을 읽어 macOS 메뉴바 팝오버에서 LLM token 사용량을 보여주는 네이티브 앱입니다.

# Product Surface

* macOS menu bar utility built with SwiftUI `MenuBarExtra`.
* Daily token usage heatmap and selected-day detail view.
* Range summary and chart for day/week/month/custom windows.
* Activity time from `ccusage blocks`.
* Menu bar usage label with configurable period and metric.
* Setup flow for Bun and `ccusage` readiness.
* Launch-at-login control.
* Claude Code integration through the bundled MCP server and plugin.

# Source Map

* App target: [`Sources/McDuck`](../Sources/McDuck)
* Core logic: [`Sources/McDuckCore`](../Sources/McDuckCore)
* MCP server: [`Sources/McDuckMCP`](../Sources/McDuckMCP), [`Sources/mcduck-mcp`](../Sources/mcduck-mcp)
* Plugin bundle: [`plugin/`](../plugin)
* Tests: [`Tests/`](../Tests)
* Release workflows: [Release Pipeline](/architecture/release-pipeline.md)

# Current Baseline

As of this wiki initialization:

* `develop` is at `a9079c8` (`fix: drain command output while process runs`).
* Latest official release is `1.2`.
* Latest snapshot release is `1.2.1-SNAPSHOT` / `snapshot-latest`.
* Local Linux session cannot run `swift test` because `swift` is not installed; macOS GitHub Actions is the verification path.

# Related Concepts

* [System Overview](/architecture/system-overview.md)
* [Source Map](/architecture/source-map.md)
* [McDuck App Module](/modules/mcduck-app.md)
* [McDuck Core Module](/modules/mcduck-core.md)
* [Build, Test, Release Runbook](/runbooks/build-test-release.md)
