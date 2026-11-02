#!/bin/sh
# Builds Wirtshausonmac.app (Apple silicon + Intel) into ./build.
# Usage: scripts/build.sh [--run] [--install]   (--install copies the app to /Applications and starts it)
set -e
cd "$(dirname "$0")/.."

[ -f Resources/AppIcon.icns ] || scripts/make-icon.sh

# one build per architecture, merged into a universal binary (works with just the Command Line Tools)
BINS=""
for arch in arm64 x86_64; do
    swift build -c release --arch $arch
    BINS="$BINS $(swift build -c release --arch $arch --show-bin-path)/Wirtshausonmac"
done
NAME=Wirtshausonmac.app
APP="build/$NAME"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create $BINS -output "$APP/Contents/MacOS/Wirtshausonmac"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Resources/bavarian "$APP/Contents/Resources/"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

case "$1 $2" in
    *--install*)
        pkill -x Wirtshausonmac 2>/dev/null && sleep 1 || true
        rm -rf "/Applications/$NAME"
        cp -R "$APP" /Applications/
        open "/Applications/$NAME"
        echo "Installed /Applications/$NAME" ;;
    *--run*)
        pkill -x Wirtshausonmac 2>/dev/null && sleep 1 || true
        open "$APP" ;;
esac
