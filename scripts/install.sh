#!/bin/zsh
# Installs Tip Share:
#  1. a Release simulator build into the simulator "Thuban iPhone" (if it exists);
#  2. a signed Release build on the paired iPhone (team from Config/Signing.xcconfig or $DEVELOPMENT_TEAM).
#     The iPhone must be unlocked.
# Usage: [DEVICE=<devicectl id or name>] scripts/install.sh
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"

CONFIG=Release scripts/build.sh || exit 1
SIM="$(xcrun simctl list devices available | sed -nE 's/^ *Thuban iPhone \(([0-9A-F-]+)\).*/\1/p' | head -1)"
if [[ -n "$SIM" ]]; then
  xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
  xcrun simctl install "$SIM" ".build/DerivedData/Build/Products/Release-iphonesimulator/Tip Share.app" \
    && echo "Installed on simulator \"Thuban iPhone\"."
fi

TEAM="${DEVELOPMENT_TEAM:-}"
[[ -z "$TEAM" && -f Config/Signing.xcconfig ]] && \
  TEAM="$(sed -nE 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*([A-Za-z0-9]+).*/\1/p' Config/Signing.xcconfig | tail -1)"
JSON="$(mktemp "${TMPDIR:-/tmp}/tipshare-devices.XXXXXX")"
xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1
PHONE="$(python3 - "$JSON" "${DEVICE:-}" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    hw, conn, props = d.get("hardwareProperties", {}), d.get("connectionProperties", {}), d.get("deviceProperties", {})
    if hw.get("platform") != "iOS" or hw.get("deviceType") != "iPhone" or conn.get("pairingState") != "paired":
        continue
    if sys.argv[2] and sys.argv[2] not in (d.get("identifier"), props.get("name")):
        continue
    print(d["identifier"]); break
PY
)"
rm -f "$JSON"
if [[ -z "$PHONE" || -z "$TEAM" ]]; then
  echo "iPhone install skipped (no paired iPhone or no team in Config/Signing.xcconfig)."; exit 0
fi

DERIVED=.build/DerivedData-Device
mkdir -p "$DERIVED"
xcodebuild -project TipShare.xcodeproj -scheme TipShare -configuration Release -derivedDataPath "$DERIVED" \
  -destination 'generic/platform=iOS' DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build > "$DERIVED/xcodebuild.log" 2>&1
if ! grep -q "\*\* BUILD SUCCEEDED \*\*" "$DERIVED/xcodebuild.log"; then
  grep -E "error: " "$DERIVED/xcodebuild.log" | sort -u | head -20
  echo "Device build failed (see $DERIVED/xcodebuild.log)."; exit 1
fi
xcrun devicectl device install app --device "$PHONE" "$DERIVED/Build/Products/Release-iphoneos/Tip Share.app" || exit 1
echo "Installed on the iPhone."
