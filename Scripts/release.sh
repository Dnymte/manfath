#!/usr/bin/env bash
#
# Build, sign, notarize, and package Manfath as a DMG.
#
# Required environment:
#   DEVELOPMENT_TEAM     — 10-char Apple Developer team ID
#   CODE_SIGN_IDENTITY   — e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE       — notarytool keychain profile name
#                          (create once: xcrun notarytool store-credentials …)
#
# Optional:
#   SKIP_NOTARIZE=1      — build + sign + DMG, skip notarization/stapling
#
# Output: build/Manfath-<version>.dmg

set -euo pipefail

cd "$(dirname "$0")/.."

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM (10-char team ID)}"
: "${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY (Developer ID Application identity)}"

SCHEME=Manfath
CONFIG=Release
BUILD_DIR="$(pwd)/build"
ARCHIVE="$BUILD_DIR/Manfath.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/Manfath.app"

VERSION=$(awk '/MARKETING_VERSION/ {gsub(/"/,"",$2); print $2; exit}' project.yml)
DMG="$BUILD_DIR/Manfath-${VERSION}.dmg"

echo "==> Regenerating Xcode project"
xcodegen generate

echo "==> Cleaning $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving ($CONFIG)"
xcodebuild \
    -project Manfath.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -archivePath "$ARCHIVE" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
    archive

echo "==> Exporting"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist Scripts/ExportOptions.plist

if [[ -z "${SKIP_NOTARIZE:-}" ]]; then
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE or pass SKIP_NOTARIZE=1}"

    ZIP="$BUILD_DIR/Manfath.zip"
    echo "==> Zipping for notarytool"
    /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

    echo "==> Submitting to notary service"
    xcrun notarytool submit "$ZIP" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "==> Stapling ticket"
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
fi

echo "==> Building styled DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir "$STAGE/.background"
cp Scripts/dmg-background.png "$STAGE/.background/"

RW_DMG="$BUILD_DIR/Manfath-rw.dmg"
hdiutil create \
    -volname "Manfath" \
    -srcfolder "$STAGE" \
    -ov -format UDRW \
    -fs HFS+ \
    "$RW_DMG"
rm -rf "$STAGE"

# Mount RW DMG and apply Finder layout via AppleScript.
MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" \
    | awk '/\/Volumes\// {for (i=3; i<=NF; i++) printf "%s%s", $i, (i==NF?"":" "); exit}')
echo "    mounted at: $MOUNT_POINT"

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "Manfath"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 740, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set text size of theViewOptions to 13
        set background picture of theViewOptions to file ".background:dmg-background.png"
        set position of item "Manfath.app" of container window to {140, 180}
        set position of item "Applications" of container window to {400, 180}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_POINT"

echo "==> Compressing DMG (UDZO)"
rm -f "$DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -f "$RW_DMG"

echo "==> Signing DMG"
codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "$DMG"

if [[ -z "${SKIP_NOTARIZE:-}" ]]; then
    echo "==> Submitting DMG to notary service"
    xcrun notarytool submit "$DMG" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "==> Stapling DMG"
    xcrun stapler staple "$DMG"
fi

echo
echo "Done. Output: $DMG"
ls -lh "$DMG"
