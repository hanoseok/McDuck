# McDuck Wiki Update Log

## 2026-06-28
* **UX adjustment**: Replaced the issue #55 chart tooltip alignment-guide placement with measured-size offsets so it sits directly above the hovered bar.
* **UX adjustment**: Reduced the issue #55 chart tooltip default width and aligned its bottom edge directly to the hovered bar top.
* **UX adjustment**: Capped the issue #55 model legend at three two-column rows and anchored the chart tooltip above the hovered bar while allowing tooltip hover/scroll.
* **UX adjustment**: Changed the issue #55 model legend to a two-column adaptive vertical grid that grows to four rows, and made the chart tooltip float above the graph without reserving layout space.

## 2026-06-27
* **UX adjustment**: Changed the issue #55 top model legend from horizontal scrolling back to bounded vertical scrolling.

## 2026-06-25
* **UX adjustment**: Moved the issue #55 token chart tooltip into a fixed area above the graph so it does not cover the chart.
* **UX adjustment**: Disabled hit testing on the issue #55 token chart tooltip overlay so it does not interrupt chart hover and flicker.
* **UX adjustment**: Reduced the issue #55 top model legend height and gated chart hover tooltip updates to day changes to avoid flicker.
* **UX adjustment**: Refined issue #55 model legend to show at most two top rows with horizontal scrolling.
* **UX adjustment**: Added progress notes for issue #55 covering the scrollable model legend and bounded token chart tooltip.

## 2026-06-22
* **Completion**: Added a progress report for issue #45 covering the automatic update check workflow, final feature verification, merged PR, and snapshot evidence.

## 2026-06-21
* **Feature**: Added a launch-started automatic app update check loop that repeats every 10 minutes from the always-present menu-bar label task.
* **UX adjustment**: Right-aligned the Settings update check action and switched available updates to blue Update install buttons in Settings and the main footer.
* **UX adjustment**: Removed the visible usage reload text from the main footer action, leaving the ccusage updated time plus an icon-only control.
* **UX adjustment**: Restored the footer's last ccusage refresh time and kept its reload action scoped to usage data only.
* **UX adjustment**: Added version information and update checking back into Settings above Quit while keeping the compact footer behavior.
* **UX adjustment**: Simplified the popover footer so usage reload is the left action, while the right side shows the app version and only reveals Update when a release is available.
* **UX adjustment**: Moved Quit into the Settings panel and moved update controls to the main popover footer's lower-right action area.
* **Feature**: Added planning/implementation notes for settings-driven app updates: Release builds check official `releases/latest`, Snapshot builds check `snapshot-latest`, and installation opens the channel-matched `.pkg` with macOS Installer.
* **Initialization**: Created the OKF-style `wiki/` bundle for McDuck project knowledge.
* **Creation**: Added root navigation, project overview, architecture/module maps, progress, decisions, retrospectives, runbooks, references, and templates.
* **Reference**: Captured the Open Knowledge Format source material in [Open Knowledge Format](references/open-knowledge-format.md).
