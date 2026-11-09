#!/bin/zsh
# Universal LyricsFlow.app inside a drag-to-Applications .dmg: VERSION=0.1.0 scripts/make_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."
export VERSION="${VERSION:-0.1.0}"
ARCHS="arm64 x86_64" scripts/bundle.sh release
STAGE="build/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R build/LyricsFlow.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
OUT="build/LyricsFlow-${VERSION}.dmg"
rm -f "$OUT"
hdiutil create -volname "LyricsFlow" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
echo "$OUT"
