#!/bin/sh
# Builds the app and zips it with a short guide into dist/, ready to send to people.
set -e
cd "$(dirname "$0")/.."
scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
OUT="dist/Wirtshaus-covers-my-Mac-$VERSION"
rm -rf "$OUT" "$OUT.zip"
mkdir -p "$OUT"
cp -R "build/Wirtshaus covers my Mac.app" "$OUT/"
cp "Zum Installieren.txt" "$OUT/"
ditto -c -k --keepParent "$OUT" "$OUT.zip"
rm -rf "$OUT"
echo "Wrote $OUT.zip"
