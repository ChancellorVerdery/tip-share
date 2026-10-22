#!/bin/zsh
# Regenerates the Xcode project and builds an unsigned simulator app.
# Usage: [CONFIG=Debug|Release] scripts/build.sh   → .build/DerivedData/Build/Products/<CONFIG>-iphonesimulator/Tip Share.app
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
CONFIG="${CONFIG:-Debug}"
xcodegen generate --quiet || exit 1
mkdir -p .build/DerivedData
xcodebuild -project TipShare.xcodeproj -scheme TipShare -configuration "$CONFIG" -derivedDataPath .build/DerivedData \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build > .build/xcodebuild-sim.log 2>&1
if ! grep -q "\*\* BUILD SUCCEEDED \*\*" .build/xcodebuild-sim.log; then
  grep -E "error: " .build/xcodebuild-sim.log | sort -u | head -20
  echo "Build failed (see .build/xcodebuild-sim.log)."; exit 1
fi
echo "Built .build/DerivedData/Build/Products/$CONFIG-iphonesimulator/Tip Share.app"
