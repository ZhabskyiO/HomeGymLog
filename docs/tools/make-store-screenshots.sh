#!/usr/bin/env bash
# Regenerate the five 6.9" App Store screenshots (m5-release spec §5.6). Provenance only, not a build step.
#
# Usage: bash docs/tools/make-store-screenshots.sh [path/to/HomeGymLog.app]
#
# Needs a Debug build (the -seed launch states are DEBUG-only); the default app path is the Debug simulator product.
# Shoots on the iPhone 17 Pro Max / iOS 26.5 simulator (1320 x 2868, a 6.9" size) in Dark with the status bar pinned to
# 9:41, full battery and signal. simctl writes RGBA PNGs and the App Store refuses alpha, so each shot is flattened onto
# black through a one-<image> wrapper SVG with rsvg-convert, which emits RGB. Intermediates live in a mktemp directory;
# the only files written are docs/release/screenshots/NN-name.png. The status-bar override is cleared on any exit.
set -euo pipefail

UDID=5236ED20-CDE1-441F-9F48-54E856A3FB90
BID=com.zhabskyi.homegymlog.ios
RSVG=/opt/homebrew/bin/rsvg-convert
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="${1:-$ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app}"
OUT="$ROOT/docs/release/screenshots"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; xcrun simctl status_bar "$UDID" clear' EXIT

[ -d "$APP" ] || { echo "no app at $APP (build Debug first)" >&2; exit 1; }
[ -x "$RSVG" ] || { echo "$RSVG not found: brew install librsvg" >&2; exit 1; }
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true      # "already booted" is fine
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance dark
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
# The first 26.5 shot after a boot can draw the Dynamic Island and corner masks (gotcha 2026-09-25).
xcrun simctl io "$UDID" screenshot "$TMP/throwaway.png" >/dev/null || true   # throwaway: a failure here is not a result

ROWS=(
  "01-home|-seed midProgram"
  "02-workout|-seed wo-swipe"
  "03-rest|-seed wo-rest"
  "04-progress|-seed progress-history -tab progress"
  "05-program|-seed midProgram -tab program"
)

for row in "${ROWS[@]}"; do
  name="${row%%|*}"
  read -r -a args <<< "${row#*|}"
  xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true   # exits 3 when the app is not running
  xcrun simctl install "$UDID" "$APP"
  xcrun simctl spawn "$UDID" defaults delete seed 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BID" "${args[@]}" >/dev/null
  sleep 3
  xcrun simctl io "$UDID" screenshot "$TMP/shot.png" >/dev/null   # stderr kept: under set -e the reason must be visible
  cat > "$TMP/wrap.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1320" height="2868"><image width="1320" height="2868" xlink:href="shot.png"/></svg>
SVG
  "$RSVG" -w 1320 -h 2868 -b '#000000' -o "$OUT/$name.png" "$TMP/wrap.svg"
  echo "$OUT/$name.png"
done
xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
