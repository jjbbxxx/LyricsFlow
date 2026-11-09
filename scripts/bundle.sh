#!/bin/zsh
# Build LyricsFlow.app with SwiftPM (no Xcode needed).
#   scripts/bundle.sh [debug|release]
#   ARCHS="arm64 x86_64" scripts/bundle.sh   # universal binary
#   VERSION=0.2.0 scripts/bundle.sh
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
VERSION="${VERSION:-0.1.0}"
# One binary per architecture, merged with lipo (works with Command Line Tools only).
BINS=()
if [[ -z "${ARCHS:-}" ]]; then
  swift build -c "$CONFIG"
  BINS+=("$(swift build -c "$CONFIG" --show-bin-path)/LyricsFlow")
else
  for a in ${=ARCHS}; do
    swift build -c "$CONFIG" --triple "${a}-apple-macosx"
    BINS+=("$(swift build -c "$CONFIG" --triple "${a}-apple-macosx" --show-bin-path)/LyricsFlow")
  done
fi
APP="build/LyricsFlow.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if (( ${#BINS[@]} > 1 )); then
  lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/LyricsFlow"
else
  cp "${BINS[1]}" "$APP/Contents/MacOS/LyricsFlow"
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>LyricsFlow</string>
  <key>CFBundleDisplayName</key><string>LyricsFlow</string>
  <key>CFBundleIdentifier</key><string>com.jbx.LyricsFlow</string>
  <key>CFBundleExecutable</key><string>LyricsFlow</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSExceptionDomains</key><dict>
    <key>kugou.com</key><dict><key>NSIncludesSubdomains</key><true/><key>NSExceptionAllowsInsecureHTTPLoads</key><true/></dict>
  </dict></dict>
  <key>NSAppleEventsUsageDescription</key><string>LyricsFlow reads the current track and playback position from Music to show synced lyrics. It never controls playback.</string>
</dict></plist>
PLIST
# Identifier-only designated requirement keeps the Automation grant valid across rebuilds.
codesign --force --sign - --identifier com.jbx.LyricsFlow -r='designated => identifier "com.jbx.LyricsFlow"' "$APP" >/dev/null
echo "$APP"
