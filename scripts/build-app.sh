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

# Copy SwiftPM resource bundles (e.g. McDuck_McDuck.bundle) into the app so
# Bundle.module resolves the bundled image at runtime.
for bundle in "$BIN_DIR"/*.bundle; do
  [[ -e "$bundle" ]] && cp -R "$bundle" "$RESOURCES_DIR/"
done

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

# App icon: build AppIcon.icns from Resources/AppIcon.png (a 1024x1024 PNG)
# when present. Info.plist references it via CFBundleIconFile=AppIcon.
ICON_SRC="$ROOT_DIR/Sources/McDuck/Resources/AppIcon.png"
if [[ -f "$ICON_SRC" ]] && command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
  ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"
  for entry in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
               "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" \
               "512 512x512" "1024 512x512@2x"; do
    set -- $entry
    sips -z "$1" "$1" "$ICON_SRC" --out "$ICONSET_DIR/icon_$2.png" >/dev/null
  done
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
  rm -rf "$(dirname "$ICONSET_DIR")"
  echo "Embedded app icon"
fi

# Compile the asset catalog into the app's main bundle as Assets.car so named
# images (e.g. MenuBarIcon used by MenuBarExtra) resolve at runtime. swift build
# does not run actool, so do it here with the Xcode tool.
XCASSETS="$ROOT_DIR/Sources/McDuck/Resources/Assets.xcassets"
if [[ -d "$XCASSETS" ]] && command -v xcrun >/dev/null 2>&1; then
  xcrun actool "$XCASSETS" \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --output-format human-readable-text >/dev/null
  echo "Compiled asset catalog"
fi

# Ad-hoc sign the bundle so it has a valid signature. This turns the
# "damaged, move to Trash" Gatekeeper block into a normal unidentified-
# developer prompt that can be bypassed with right-click > Open.
# (Full notarization still requires a paid Apple Developer ID.)
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR"
  echo "Ad-hoc signed $APP_DIR"
fi

echo "Built $APP_DIR"
