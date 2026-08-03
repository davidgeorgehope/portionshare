#!/bin/zsh
# Builds PortionShare.app into dist/.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="dist/PortionShare.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/PortionShare "$APP/Contents/MacOS/PortionShare"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature keeps the Screen Recording permission grant stable
# across rebuilds.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open $APP"
