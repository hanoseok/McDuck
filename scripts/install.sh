#!/bin/bash
# One-line installer for McDuck.
#
#   # latest:
#   curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/install.sh | bash
#
#   # a specific version (pass the tag as an argument):
#   curl -fsSL https://github.com/hanoseok/McDuck/releases/download/v0.0.20/install.sh | bash -s -- v0.0.20
#
# Files fetched with curl are NOT flagged with com.apple.quarantine, so
# Gatekeeper does not block them: no `xattr`, no "right-click > Open", no
# System Settings. The only prompt is the administrator password that
# `installer` needs to write to /Applications.
set -euo pipefail

REPO="hanoseok/McDuck"
TAG="${1:-}"   # optional release tag, e.g. 1.0 or v0.0.20; empty means latest

# Without an explicit tag, resolve the newest release by following the
# releases/latest redirect (no API token, no rate limit) so we can show and
# install an exact version instead of an opaque "latest".
if [ -z "$TAG" ]; then
  EFFECTIVE="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null || true)"
  case "$EFFECTIVE" in
    */releases/tag/*) TAG="${EFFECTIVE##*/}" ;;
  esac
fi

if [ -n "$TAG" ]; then
  PKG_URL="https://github.com/$REPO/releases/download/$TAG/McDuck-$TAG.pkg"
  VER="v${TAG#v}"   # normalize so 1.0 and v1.0 both display as v1.0
else
  # Could not resolve a version: fall back to the stable latest asset.
  PKG_URL="https://github.com/$REPO/releases/latest/download/McDuck.pkg"
  VER="(latest)"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading McDuck $VER ..."
curl -fL --retry 3 -o "$TMP/McDuck.pkg" "$PKG_URL"

echo "Installing McDuck $VER (administrator password required)..."
sudo installer -pkg "$TMP/McDuck.pkg" -target /

echo "Done. McDuck $VER is installed and launching."
