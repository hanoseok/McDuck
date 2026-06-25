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
* Follow-up: changed the top model legend from vertical scrolling to a two-row horizontal scroller.
* Follow-up: reduced the two-row legend height and only updates hover tooltip state when the hovered chart day changes, avoiding flicker from small pointer movements inside the same day.
* Follow-up: disabled hit testing on the tooltip overlay so the tooltip cannot interrupt the chart hover stream when it appears under the cursor.
* Follow-up: moved the tooltip into a fixed area above the chart, removing pointer-location tracking so the tooltip never covers the graph itself.

# Evidence

* Added `Tests/McDuckTests/TokenBarChartLayoutTests.swift` to guard the custom legend, independent plot height, and bounded tooltip rows.
* Focused TDD evidence:
  * Red: `swift test --filter TokenBarChartLayoutTests` failed with the built-in legend and outer chart height.
  * Red: `swift test --filter TokenBarChartLayoutTests.tooltipBoundsModelRows` failed before tooltip row bounding.
  * Red: `swift test --filter TokenBarChartLayoutTests.tokenChartUsesTwoRowHorizontalModelLegend` failed while the legend still used vertical scrolling.
  * Red: `swift test --filter TokenBarChartLayoutTests` failed before the compact legend constants and day-change-only hover update helper existed.
  * Red: `swift test --filter TokenBarChartLayoutTests.tooltipOverlayAllowsChartHoverToContinue` failed before the tooltip overlay ignored hit testing.
  * Red: `swift test --filter TokenBarChartLayoutTests.tooltipRendersAboveChart` failed while the tooltip still rendered inside the chart overlay.
  * Red: `swift test --filter TokenBarChartLayoutTests.tooltipAboveChartDoesNotTrackPointerLocation` failed while pointer-location state still existed.
  * Green: `swift test --filter TokenBarChartLayoutTests` passed after implementation.

# Next

* Run full local verification: `swift test`, `swift build`, and `scripts/build-app.sh`.
* Cut and confirm the next snapshot after merging to `develop`.

# Related Concepts

* [McDuck App](../modules/mcduck-app.md)
* [McDuck Core](../modules/mcduck-core.md)
* [Build, Test, Release](../runbooks/build-test-release.md)
