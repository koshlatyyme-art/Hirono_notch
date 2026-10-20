#!/bin/bash
# Builds build/NotchBuddy.app from the SwiftPM package.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f Assets/Character/body.png ]; then
    echo "Character layers are missing: run tools/rig/.venv/bin/python -I tools/rig/cut.py first" >&2
    exit 1
fi

swift build -c release --product NotchBuddy
APP=build/NotchBuddy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Character"
cp "$(swift build -c release --show-bin-path)/NotchBuddy" "$APP/Contents/MacOS/"
cp scripts/Info.plist "$APP/Contents/"
cp Assets/Character/* "$APP/Contents/Resources/Character/"
codesign --force --sign "Apple Development" "$APP"
echo "$APP"
