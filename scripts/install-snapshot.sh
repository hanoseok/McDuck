#!/bin/bash
# One-line installer for McDuck *snapshot* (test) builds.
#
#   # latest snapshot:
#   curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash
#
#   # a specific snapshot version (pass the tag as an argument):
#   curl -fsSL https://github.com/hanoseok/McDuck/releases/download/1.0.0-SNAPSHOT/install-snapshot.sh | bash -s -- 1.0.0-SNAPSHOT
#
# Snapshot builds are GitHub prereleases published from `develop`; they do not
# affect the official `releases/latest` produced from `main`.
#
# Files fetched with curl are NOT flagged with com.apple.quarantine, so
# Gatekeeper does not block them: no `xattr`, no "right-click > Open", no
# System Settings. The only prompt is the administrator password that
# `installer` needs to write to /Applications.
set -euo pipefail

REPO="hanoseok/McDuck"
TAG="${1:-}"   # optional snapshot tag, e.g. 1.0.0-SNAPSHOT; empty means latest

if [ -n "$TAG" ]; then
  PKG_URL="https://github.com/$REPO/releases/download/$TAG/McDuck-$TAG.pkg"
  LABEL="$TAG"
else
  PKG_URL="https://github.com/$REPO/releases/download/snapshot-latest/McDuck.pkg"
  LABEL="(snapshot-latest)"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading McDuck snapshot $LABEL ..."
curl -fL --retry 3 -o "$TMP/McDuck.pkg" "$PKG_URL"

echo "Installing McDuck (administrator password required)..."
sudo installer -pkg "$TMP/McDuck.pkg" -target /

echo "Done. McDuck snapshot $LABEL is installed and launching."
