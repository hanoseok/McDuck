#!/bin/bash
# McDuck installer: quits a running copy, installs to /Applications, clears the
# Gatekeeper quarantine flag, and launches the app. Double-click in Finder, or
# run `bash "Install McDuck.command"` from Terminal (bypasses quarantine).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SRC="$DIR/McDuck.app"
APP_DST="/Applications/McDuck.app"

echo "Installing McDuck..."

# 1) Quit McDuck if it is currently running.
if pgrep -x McDuck >/dev/null 2>&1; then
  echo "• Quitting the running McDuck..."
  osascript -e 'tell application "McDuck" to quit' >/dev/null 2>&1 || true
  sleep 1
  pkill -x McDuck 2>/dev/null || true
fi

# 2) Copy into /Applications, falling back to running in place if not writable.
if [ -d "$APP_SRC" ]; then
  if rm -rf "$APP_DST" 2>/dev/null && cp -R "$APP_SRC" "$APP_DST" 2>/dev/null; then
    echo "• Installed to $APP_DST"
  else
    echo "• Could not write to /Applications; running from this folder instead."
    APP_DST="$APP_SRC"
  fi
elif [ -d "$APP_DST" ]; then
  echo "• Using existing $APP_DST"
else
  echo "McDuck.app not found next to this installer." >&2
  exit 1
fi

# 3) Remove the quarantine attribute so Gatekeeper allows launch.
echo "• Clearing quarantine flag..."
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true

# 4) Launch.
echo "• Opening McDuck..."
open "$APP_DST"

echo "Done. McDuck should appear in the menu bar."
