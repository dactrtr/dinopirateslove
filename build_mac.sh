#!/bin/bash
# Build a standalone macOS .app for DinoPirates Love.
# Fuses the game (source/, minus DOCS) into a copy of the bundled universal love.app.
# Usage: ./build_mac.sh
set -e
cd "$(dirname "$0")"

APP_NAME="DinoPirates"
BUNDLE_ID="com.dinopirates.game"
DIST="dist"
LOVE_APP="love.app"   # bundled universal LÖVE 11.5 (x86_64 + arm64)

if [ ! -d "$LOVE_APP" ]; then
    echo "❌ $LOVE_APP not found in repo root."; exit 1
fi

echo "🧹 Cleaning $DIST/ ..."
rm -rf "$DIST"
mkdir -p "$DIST"

# 1. Build the .love (zip of source/ contents so main.lua sits at the archive root).
#    Exclude the Playdate reference (DOCS/) and macOS junk to keep it small.
echo "📦 Building $APP_NAME.love ..."
( cd source && zip -9 -r -X "../$DIST/$APP_NAME.love" . \
    -x "DOCS/*" -x "*.DS_Store" -x "__MACOSX/*" >/dev/null )
echo "   size: $(du -h "$DIST/$APP_NAME.love" | cut -f1)"

# 2. Assemble the .app from a copy of love.app.
echo "🍎 Assembling $APP_NAME.app ..."
cp -R "$LOVE_APP" "$DIST/$APP_NAME.app"
cp "$DIST/$APP_NAME.love" "$DIST/$APP_NAME.app/Contents/Resources/"

# 3. Patch Info.plist: name + bundle id, and drop the generic .love document
#    association so the bundle launches THIS game directly.
PLIST="$DIST/$APP_NAME.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME"        "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes"        "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :UTExportedTypeDeclarations"   "$PLIST" 2>/dev/null || true

# 4. Ad-hoc codesign so Gatekeeper on Apple Silicon doesn't kill the modified bundle.
echo "🔏 Ad-hoc signing ..."
codesign --force --deep --sign - "$DIST/$APP_NAME.app" 2>/dev/null \
    && echo "   signed (ad-hoc)" || echo "   ⚠️ codesign skipped/failed (app still runs locally)"

echo "✅ Done → $DIST/$APP_NAME.app"
