#!/bin/bash
# One-line installer for McDuck.
#
#   # latest:
#   curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/remote-install.sh | bash
#
#   # a specific version (pass the tag as an argument):
#   curl -fsSL https://github.com/hanoseok/McDuck/releases/download/v0.0.20/remote-install.sh | bash -s -- v0.0.20
#
# Files fetched with curl are NOT flagged with com.apple.quarantine, so
# Gatekeeper does not block them: no `xattr`, no "right-click > Open", no
# System Settings. The only prompt is the administrator password that
# `installer` needs to write to /Applications.
set -euo pipefail

REPO="hanoseok/McDuck"
TAG="${1:-}"   # optional release tag, e.g. v0.0.20; empty means latest

if [ -n "$TAG" ]; then
  PKG_URL="https://github.com/$REPO/releases/download/$TAG/McDuck-$TAG.pkg"
  LABEL="$TAG"
else
  PKG_URL="https://github.com/$REPO/releases/latest/download/McDuck.pkg"
  LABEL="(latest)"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading McDuck $LABEL ..."
curl -fL --retry 3 -o "$TMP/McDuck.pkg" "$PKG_URL"

echo "Installing McDuck (administrator password required)..."
sudo installer -pkg "$TMP/McDuck.pkg" -target /

echo "Done. McDuck $LABEL is installed and launching."
