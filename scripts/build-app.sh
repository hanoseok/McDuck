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

# Copy the title (header) image into the app so AppImages can load it.
if [[ -f "$ROOT_DIR/Resources/McDuck-title.png" ]]; then
  cp "$ROOT_DIR/Resources/McDuck-title.png" "$RESOURCES_DIR/McDuck-title.png"
fi

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

# App icon: build AppIcon.icns from the title image (Resources/McDuck-title.png)
# so the Finder/Dock icon matches the popover header. Info.plist references the
# result via CFBundleIconFile=AppIcon.
ICON_SRC="$ROOT_DIR/Resources/McDuck-title.png"
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

# Regenerate the MenuBarIcon imageset from Resources/McDuck-menubar.png (the
# 1x/2x/3x sizes) so the menu bar shows that image, then compile the catalog.
MENUBAR_SRC="$ROOT_DIR/Resources/McDuck-menubar.png"
IMGSET="$ROOT_DIR/Resources/Assets.xcassets/MenuBarIcon.imageset"
if [[ -f "$MENUBAR_SRC" ]] && [[ -d "$IMGSET" ]] && command -v sips >/dev/null 2>&1; then
  # 24pt at 1x/2x/3x (icon-18/36/54.png are the 1x/2x/3x slot filenames).
  for entry in "24 icon-18.png" "48 icon-36.png" "72 icon-54.png"; do
    set -- $entry
    sips -z "$1" "$1" "$MENUBAR_SRC" --out "$IMGSET/$2" >/dev/null
  done
  echo "Updated menu bar icon from McDuck-menubar.png"
fi

# Compile the asset catalog into the app's main bundle as Assets.car so named
# images (e.g. MenuBarIcon used by MenuBarExtra) resolve at runtime. swift build
# does not run actool, so do it here with the Xcode tool.
XCASSETS="$ROOT_DIR/Resources/Assets.xcassets"
if [[ -d "$XCASSETS" ]] && command -v xcrun >/dev/null 2>&1; then
  xcrun actool "$XCASSETS" \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --output-format human-readable-text >/dev/null
  echo "Compiled asset catalog"
fi

# Bundle the Claude Code plugin marketplace (MCP server + usage-report skill)
# into the app so installing McDuck also lays down a ready-to-add LOCAL
# marketplace:
#   /plugin marketplace add /Applications/McDuck.app/Contents/Resources/ClaudePlugin
#   /plugin install mcduck@mcduck
# The prebuilt mcduck-mcp binary travels inside the plugin (plugin/bin/
# mcduck-mcp-bin), so the server runs with no Swift toolchain and no network.
# Guarded so a bundling hiccup never fails the primary app build.
PLUGIN_SRC="$ROOT_DIR/plugin"
MARKET_SRC="$ROOT_DIR/.claude-plugin/marketplace.json"
if [[ -d "$PLUGIN_SRC" && -f "$MARKET_SRC" ]]; then
  if swift build -c release --product mcduck-mcp; then
    PLUGIN_DEST="$RESOURCES_DIR/ClaudePlugin"
    if (
      set -e
      rm -rf "$PLUGIN_DEST"
      mkdir -p "$PLUGIN_DEST/.claude-plugin"
      cp "$MARKET_SRC" "$PLUGIN_DEST/.claude-plugin/marketplace.json"
      cp -R "$PLUGIN_SRC" "$PLUGIN_DEST/plugin"
      cp "$BIN_DIR/mcduck-mcp" "$PLUGIN_DEST/plugin/bin/mcduck-mcp-bin"
      chmod +x "$PLUGIN_DEST/plugin/bin/mcduck-mcp" "$PLUGIN_DEST/plugin/bin/mcduck-mcp-bin"
      # Sign the nested server binary so Gatekeeper allows the plugin to exec it.
      if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - "$PLUGIN_DEST/plugin/bin/mcduck-mcp-bin"
      fi
    ); then
      echo "Bundled Claude plugin marketplace into $PLUGIN_DEST"
    else
      echo "warning: plugin marketplace bundling failed; continuing without it" >&2
      rm -rf "$PLUGIN_DEST"
    fi
  else
    echo "warning: mcduck-mcp build failed; skipping plugin bundle" >&2
  fi
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
