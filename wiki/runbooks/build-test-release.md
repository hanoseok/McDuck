---
type: Runbook
title: Build, Test, Release
description: Repeatable commands and checks for validating and publishing McDuck builds.
resource: https://github.com/hanoseok/McDuck/blob/develop/docs/BUILD.md
tags: [runbook, build, test, release, github-actions]
timestamp: 2026-06-21T06:44:10Z
---
# Local macOS Verification

Run on macOS 15+ with Xcode 26 / Swift 6.2+:

```bash
swift test
swift build
scripts/build-app.sh
open dist/McDuck.app
```

The app bundle is written to `dist/McDuck.app`; `dist/` is not committed.

# Linux Agent Limitation

This Linux session cannot directly build the SwiftUI/macOS targets. If `swift` is unavailable, use GitHub Actions status as verification evidence and state the local limitation explicitly.

# Stable Release

Stable releases are tag-based on `main`:

```bash
git checkout main && git pull
git tag 1.2
git push origin 1.2
```

This triggers `.github/workflows/release.yml` and publishes `McDuck-1.2` with `.pkg`, `McDuck.pkg`, zip, checksum, installer script, and optional MCP binary.

# Snapshot Release

Snapshots are tag-based on `develop`:

```bash
git checkout develop && git pull
git tag 1.2.1-SNAPSHOT
git push origin 1.2.1-SNAPSHOT
```

This triggers `.github/workflows/snapshot.yml` and publishes both a pinned prerelease and moving `snapshot-latest`.

# Agent Bridge

When tag push or `workflow_dispatch` is unavailable to an agent:

1. Update `.github/cut-snapshot.txt` or `.github/cut-release.txt`.
2. Push a work branch.
3. Merge through PR to `develop` or `main`.
4. Verify `Cut (bridge)` and the dispatched build workflow.

# Install Commands

```bash
# Latest stable
curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/install.sh | bash

# Latest snapshot
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash
```

# Related Concepts

* [Release Pipeline](/architecture/release-pipeline.md)
* [Project Overview](/project-overview.md)
