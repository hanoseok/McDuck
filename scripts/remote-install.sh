#!/bin/bash
# One-line installer for McDuck.
#
#   curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/remote-install.sh | bash
#
# Downloads the latest .pkg directly from the "latest" release (no GitHub API
# call, so no anonymous rate-limit 403). Files fetched with curl are NOT flagged
# with com.apple.quarantine, so Gatekeeper does not block them: no `xattr`, no
# "right-click > Open", no System Settings. The only prompt is the administrator
# password that `installer` needs to write to /Applications.
set -euo pipefail

PKG_URL="https://github.com/hanoseok/McDuck/releases/latest/download/McDuck.pkg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading the latest McDuck..."
curl -fL --retry 3 -o "$TMP/McDuck.pkg" "$PKG_URL"

echo "Installing McDuck (administrator password required)..."
sudo installer -pkg "$TMP/McDuck.pkg" -target /

echo "Done. McDuck is installed and launching."
