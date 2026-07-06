#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCHEME="${SCHEME:-CodeEdit}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$REPO_ROOT/.build/derived-data}"
APP_PATH="${APP_PATH:-$DERIVED_DATA_PATH/Build/Products/Release/CodeEdit.app}"
INSTALL_TO_APPLICATIONS="${INSTALL_TO_APPLICATIONS:-0}"

cd "$REPO_ROOT"

if [ ! -e /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator ]; then
  echo "Xcode is missing CoreSimulator.framework."
  echo "Run 'xcodebuild -runFirstLaunch' or reinstall Xcode / the simulator support components."
  exit 1
fi

echo "Building release $SCHEME"
xcodebuild \
  -project CodeEdit.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

echo "Built app at $APP_PATH"

if [ "$INSTALL_TO_APPLICATIONS" = "1" ]; then
  echo "Copying to /Applications"
  cp -R "$APP_PATH" /Applications/
fi
