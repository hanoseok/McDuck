#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/McDuck.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build -c release --product McDuck
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/McDuck" "$MACOS_DIR/McDuck"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/McDuck"

# Stamp the app bundle with a release version when provided.
# MCDUCK_VERSION sets CFBundleShortVersionString (e.g. 1.2.0).
# MCDUCK_BUILD sets CFBundleVersion (e.g. a build number); defaults to 1.
PLIST="$CONTENTS_DIR/Info.plist"
if [[ -n "${MCDUCK_VERSION:-}" ]]; then
  SHORT_VERSION="${MCDUCK_VERSION#v}"
  BUILD_VERSION="${MCDUCK_BUILD:-1}"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VERSION" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_VERSION" "$PLIST"
  echo "Stamped version $SHORT_VERSION (build $BUILD_VERSION)"
fi

echo "Built $APP_DIR"
