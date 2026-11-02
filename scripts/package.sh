#!/bin/sh
# Builds the app and zips it with a short guide into dist/, ready to send to people.
set -e
cd "$(dirname "$0")/.."
scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
OUT="dist/Wirtshausonmac-$VERSION"
rm -rf "$OUT" "$OUT.zip"
mkdir -p "$OUT"
cp -R build/Wirtshausonmac.app "$OUT/"
cp "Zum Installieren.txt" "$OUT/"
xattr -cr "$OUT"
# --norsrc keeps the ._ files of extended attributes out of the zip
ditto -c -k --norsrc --keepParent "$OUT" "$OUT.zip"
rm -rf "$OUT"
echo "Wrote $OUT.zip"
