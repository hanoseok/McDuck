---
type: Architecture
title: Release Pipeline
description: Tag-based GitHub Actions release and snapshot pipeline for McDuck.
resource: https://github.com/hanoseok/McDuck/actions
tags: [release, ci, github-actions, snapshot, packaging]
timestamp: 2026-06-21T06:44:10Z
---
# Channels

| Channel | Branch | Version shape | Workflow | Output |
| --- | --- | --- | --- | --- |
| Stable | `main` | `MAJOR.MINOR` (for example `1.2`) | `.github/workflows/release.yml` | Official release, `releases/latest` |
| Snapshot | `develop` | `X.Y.Z-SNAPSHOT` | `.github/workflows/snapshot.yml` | Prerelease and moving `snapshot-latest` |
| PR CI | PR into `develop` or `main` | n/a | `.github/workflows/ci.yml` | `swift test` matrix on macOS 15 and 26 |
| Agent bridge | PR merge with marker file | marker content | `.github/workflows/cut.yml` | Dispatches release/snapshot workflow |

# Packaging Outputs

Stable and snapshot builds publish:

* versioned `.pkg`
* stable `McDuck.pkg`
* macOS zip bundle
* SHA-256 checksum file
* installer script (`install.sh` or `install-snapshot.sh`)
* optional `mcduck-mcp-macos` binary if the MCP server build succeeds

# Agent Constraint

Cloud/Linux agent sessions cannot push tag refs or dispatch workflows directly in this repository. For agent-triggered builds, update the appropriate marker file and merge through PR:

* `.github/cut-release.txt` → merge to `main`
* `.github/cut-snapshot.txt` → merge to `develop`

# Related Concepts

* [Build, Test, Release Runbook](/runbooks/build-test-release.md)
* [Initial OKF Wiki Setup Progress](/progress/2026-06-21-okf-wiki-foundation.md)
