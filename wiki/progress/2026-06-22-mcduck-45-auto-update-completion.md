---
type: Progress Report
title: Issue 45 Automatic Update Completion
description: Completion cleanup for the Settings and footer update-check workflow.
resource: https://github.com/hanoseok/McDuck/pull/54
tags: [progress, mcduck, updates, release]
timestamp: 2026-06-21T22:52:50Z
---
# Summary

Issue #45 added app-update awareness to McDuck's compact menu-bar popover. Settings now owns version information, update checking, and Quit, while the main footer keeps usage refresh on the left and only shows a blue Update action on the right when a newer release is available.

# Completed

* Merged the final implementation PR into `develop`: [PR #54](https://github.com/hanoseok/McDuck/pull/54), merge commit `7954ab72d02f6cc4c370e2fcda8d24da63f2ba63`.
* Added a 10-minute automatic update check loop from the always-present menu-bar label task so checks start at app launch.
* Preserved the ccusage refresh footer behavior: icon-only usage refresh on the left and last refresh time in `HH:mm` form.
* Kept update-install actions channel-aware: release builds check `releases/latest`, snapshot builds check `snapshot-latest`.
* Confirmed snapshot publication for the implementation commit: [1.3.8-SNAPSHOT](https://github.com/hanoseok/McDuck/releases/tag/1.3.8-SNAPSHOT).

# Evidence

* Feature worktree verification passed on 2026-06-22 KST: `git diff --check`, `swift test`, `swift build`, and `scripts/build-app.sh`.
* `swift test` reported 150 tests across 20 suites passing.
* `scripts/build-app.sh` produced `dist/McDuck.app`; generated icon PNG changes were restored and the feature worktree returned clean.
* Installation commands for the verified snapshot:
  ```bash
  curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash
  curl -fsSL https://github.com/hanoseok/McDuck/releases/download/1.3.8-SNAPSHOT/install-snapshot.sh | bash
  ```

# Blockers / Risks

* No open implementation blocker remains.
* A final develop snapshot is still required after this cleanup documentation is pushed so the completion record is included in a published build lineage.

# Next

* Cut and confirm `1.3.9-SNAPSHOT` from `develop`.
* Update and close GitHub issue #45 after the cleanup snapshot is confirmed.

# Related Concepts

* [McDuck App](../modules/mcduck-app.md)
* [McDuck Core](../modules/mcduck-core.md)
* [Build, Test, Release](../runbooks/build-test-release.md)
