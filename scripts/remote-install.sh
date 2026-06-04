#!/bin/bash
# One-line installer for McDuck.
#
#   curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/remote-install.sh | bash
#
# Files downloaded with curl are NOT flagged with com.apple.quarantine, so
# Gatekeeper does not block them: no `xattr`, no "right-click > Open", and no
# System Settings detour. The only prompt is the administrator password that
# `installer` needs to write to /Applications.
set -euo pipefail

REPO="hanoseok/McDuck"

echo "Looking up the latest McDuck release..."
TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
if [ -z "${TAG:-}" ]; then
  echo "Could not determine the latest release." >&2
  exit 1
fi

PKG_URL="https://github.com/$REPO/releases/download/$TAG/McDuck-$TAG.pkg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading McDuck $TAG ..."
curl -fsSL -o "$TMP/McDuck.pkg" "$PKG_URL"

echo "Installing McDuck $TAG (administrator password required)..."
sudo installer -pkg "$TMP/McDuck.pkg" -target /

echo "Done. McDuck $TAG is installed and launching."
