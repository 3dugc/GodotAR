#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="${1:-rokid}"
PACKAGE="${2:-org.godotengine.godotxrfoundation}"
DURATION="${3:-30}"
APK_PATH="${APK_PATH:-}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
LOG_PATH="$OUT_DIR/${GATE}-${STAMP}.log"
REPORT_PATH="$OUT_DIR/${GATE}-${STAMP}.md"

mkdir -p "$OUT_DIR"

if ! command -v adb >/dev/null 2>&1; then
	echo "adb not found. Install Android platform tools and connect Rokid/Android device." >&2
	exit 2
fi

if [ -n "$APK_PATH" ]; then
	echo "Installing APK: $APK_PATH"
	adb install -r "$APK_PATH"
fi

echo "Connected devices:"
adb devices

echo "Clearing logcat..."
adb logcat -c || true

echo "Launching package: $PACKAGE"
adb shell monkey -p "$PACKAGE" 1 >/dev/null || true

echo "Collecting logcat for ${DURATION}s -> $LOG_PATH"
adb logcat -v brief > "$LOG_PATH" &
LOGCAT_PID="$!"
sleep "$DURATION"
kill "$LOGCAT_PID" >/dev/null 2>&1 || true
wait "$LOGCAT_PID" >/dev/null 2>&1 || true

echo "Validating gate: $GATE"
node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
	--gate "$GATE" \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS

echo "Report: $REPORT_PATH"
