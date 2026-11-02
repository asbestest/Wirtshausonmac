#!/bin/sh
# Renders the app icon with the app's own card artwork and packs it into Resources/AppIcon.icns.
set -e
cd "$(dirname "$0")/.."
swift build -c release
TMP=$(mktemp -d)
"$(swift build -c release --show-bin-path)/Wirtshausonmac" --icon "$TMP/icon.png"
SET="$TMP/AppIcon.iconset"
mkdir "$SET"
for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d "$TMP/icon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
rm -rf "$TMP"
echo "Wrote Resources/AppIcon.icns"
