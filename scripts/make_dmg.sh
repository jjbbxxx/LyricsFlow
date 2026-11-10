#!/bin/zsh
# Universal LyricsFlow.app in an installer .dmg with a drag-to-Applications layout and
# first-launch help text: VERSION=0.1.0 scripts/make_dmg.sh
# Window layout is set through Finder (AppleScript), so run it in a logged-in desktop session.
set -euo pipefail
cd "$(dirname "$0")/.."
export VERSION="${VERSION:-0.1.0}"
VOL="LyricsFlow"
ARCHS="arm64 x86_64" scripts/bundle.sh release

swift scripts/make_dmg_background.swift build/dmg-bg.png

STAGE="build/dmg-stage"
RW="build/LyricsFlow-rw.dmg"
OUT="build/LyricsFlow-${VERSION}.dmg"
rm -rf "$STAGE" "$RW" "$OUT"
mkdir -p "$STAGE/.background"
cp -R build/LyricsFlow.app "$STAGE/"
cp build/dmg-bg.png "$STAGE/.background/bg.png"
ln -s /Applications "$STAGE/Applications"

hdiutil detach "/Volumes/$VOL" >/dev/null 2>&1 || true
hdiutil create -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
hdiutil attach "$RW" -readwrite -noverify -noautoopen >/dev/null

# Content area is 660x440 pt; the window frame adds the title bar.
perl -e 'alarm 120; exec @ARGV' osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 588}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set text size of opts to 13
    set background picture of opts to file ".background:bg.png"
    set position of item "LyricsFlow.app" of container window to {170, 185}
    set position of item "Applications" of container window to {490, 185}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "/Volumes/$VOL" >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -f "$RW"
echo "$OUT"
