---
type: Progress Report
title: Issue 55 Scrollable Model Legend
description: Planning and implementation notes for keeping the token chart usable when many models are present.
resource: https://github.com/hanoseok/McDuck/issues/55
tags: [progress, mcduck, chart, model-breakdown, ui]
timestamp: 2026-06-25T01:07:00Z
---
# Summary

Issue #55 fixes the popover token chart when `ccusage --breakdown` returns many model names. The previous Swift Charts built-in legend expanded vertically inside the chart, leaving too little room for the bars and axis labels.

# Implementation

* Moved model names out of the built-in Charts legend into a bounded vertical scroll area.
* Kept the chart plot at a fixed internal height so the model list cannot shrink the graph.
* Added an explicit model color domain so legend swatches and stacked bar colors stay aligned.
* Bounded the hover tooltip's per-model rows so many models do not cover the chart.

# Evidence

* Added `Tests/McDuckTests/TokenBarChartLayoutTests.swift` to guard the custom legend, independent plot height, and bounded tooltip rows.
* Focused TDD evidence:
  * Red: `swift test --filter TokenBarChartLayoutTests` failed with the built-in legend and outer chart height.
  * Red: `swift test --filter TokenBarChartLayoutTests.tooltipBoundsModelRows` failed before tooltip row bounding.
  * Green: `swift test --filter TokenBarChartLayoutTests` passed after implementation.

# Next

* Run full local verification: `swift test`, `swift build`, and `scripts/build-app.sh`.
* Cut and confirm the next snapshot after merging to `develop`.

# Related Concepts

* [McDuck App](../modules/mcduck-app.md)
* [McDuck Core](../modules/mcduck-core.md)
* [Build, Test, Release](../runbooks/build-test-release.md)
