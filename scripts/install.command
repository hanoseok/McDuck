#!/bin/bash
# McDuck installer: quits a running copy, installs to /Applications, clears the
# Gatekeeper quarantine flag (with administrator privileges), and launches the
# app. Double-click in Finder, or run `bash "Install McDuck.command"`.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SRC="$DIR/McDuck.app"
APP_DST="/Applications/McDuck.app"

echo "Installing McDuck..."
echo "• Administrator password is required to install and clear quarantine."
if ! sudo -v; then
  echo "Could not obtain administrator privileges. Aborting." >&2
  exit 1
fi
# Keep the sudo credential alive until this script finishes.
while true; do sudo -n true; sleep 30; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

# 1) Quit McDuck if it is currently running.
if pgrep -x McDuck >/dev/null 2>&1; then
  echo "• Quitting the running McDuck..."
  osascript -e 'tell application "McDuck" to quit' >/dev/null 2>&1 || true
  sleep 1
  pkill -x McDuck 2>/dev/null || true
fi

# 2) Install into /Applications with elevated privileges.
if [ -d "$APP_SRC" ]; then
  echo "• Installing to $APP_DST ..."
  sudo rm -rf "$APP_DST"
  sudo cp -R "$APP_SRC" "$APP_DST"
elif [ ! -d "$APP_DST" ]; then
  echo "McDuck.app not found next to this installer." >&2
  exit 1
fi

# 3) Remove the quarantine attribute (with admin rights) so Gatekeeper allows it.
echo "• Clearing quarantine flag..."
sudo xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true

# 4) Launch.
echo "• Opening McDuck..."
open "$APP_DST"

echo "Done. McDuck should appear in the menu bar."
