#!/usr/bin/env bash
# Build and launch through LaunchServices so macOS attributes permissions to Capt, not the terminal.
set -euo pipefail
cd "$(dirname "$0")/.."
Scripts/build.sh "${1:-release}"
pkill -x Capt 2>/dev/null || true
open build/Capt.app
