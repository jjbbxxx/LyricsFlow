#!/bin/zsh
# Build LyricsFlow.app with SwiftPM (no Xcode needed). Usage: scripts/bundle.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/LyricsFlow"
APP="build/LyricsFlow.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LyricsFlow"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>LyricsFlow</string>
  <key>CFBundleDisplayName</key><string>LyricsFlow</string>
  <key>CFBundleIdentifier</key><string>com.jbx.LyricsFlow</string>
  <key>CFBundleExecutable</key><string>LyricsFlow</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>LyricsFlow reads the current track and playback position from Music to show synced lyrics. It never controls playback.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null
echo "$APP"
