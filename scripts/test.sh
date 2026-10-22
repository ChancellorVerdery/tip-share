#!/bin/zsh
# Runs the split-logic tests (TipShareCore) on the Mac.
set -euo pipefail
cd "$(dirname "$0")/../Packages/TipShareCore"
swift test
