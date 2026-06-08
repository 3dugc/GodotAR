#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="${1:-rokid}"
PACKAGE="${2:-org.godotengine.godotxrfoundation}"
DURATION="${3:-30}"
APK_PATH="${APK_PATH:-}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
CAPTURE_MEDIA="${CAPTURE_MEDIA:-1}"
ALLOW_MISSING_MEDIA="${ALLOW_MISSING_MEDIA:-0}"
VIDEO_SECONDS="${VIDEO_SECONDS:-15}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
LOG_PATH="$OUT_DIR/${GATE}-${STAMP}.log"
REPORT_PATH="$OUT_DIR/${GATE}-${STAMP}.md"
SCREENSHOT_PATH="$OUT_DIR/${GATE}-${STAMP}.png"
VIDEO_PATH="$OUT_DIR/${GATE}-${STAMP}.mp4"
PROFILE_PATH="$OUT_DIR/${GATE}-${STAMP}-device.md"
PROFILE_JSON_PATH="$OUT_DIR/${GATE}-${STAMP}-device.json"
PROFILE_ANALYSIS_PATH="$OUT_DIR/${GATE}-${STAMP}-device-analysis.md"
REMOTE_VIDEO="/sdcard/gxf-${GATE}-${STAMP}.mp4"

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

echo "Collecting Android device profile -> $PROFILE_PATH"
if ! node "$PROJECT_ROOT/tools/c00/collect_android_device_profile.js" \
	--gate "$GATE" \
	--package "$PACKAGE" \
	--report "$PROFILE_PATH" \
	--json "$PROFILE_JSON_PATH"; then
	echo "Android device profile collection failed; continuing to smoke collection."
fi
if [ -f "$PROFILE_JSON_PATH" ]; then
	echo "Analyzing Android device profile -> $PROFILE_ANALYSIS_PATH"
	if ! node "$PROJECT_ROOT/tools/c00/analyze_android_device_profile.js" \
		--gate "$GATE" \
		--json "$PROFILE_JSON_PATH" \
		--report "$PROFILE_ANALYSIS_PATH"; then
		echo "Android device profile analysis reported failures; final gate still depends on smoke log validation."
	fi
fi

echo "Clearing logcat..."
adb logcat -c || true

echo "Launching package: $PACKAGE"
adb shell monkey -p "$PACKAGE" 1 >/dev/null || true

if [ "$CAPTURE_MEDIA" != "0" ]; then
	echo "Recording ${VIDEO_SECONDS}s screen capture -> $VIDEO_PATH"
	adb shell rm -f "$REMOTE_VIDEO" >/dev/null 2>&1 || true
	adb shell screenrecord --time-limit "$VIDEO_SECONDS" "$REMOTE_VIDEO" &
	SCREENRECORD_PID="$!"
else
	SCREENRECORD_PID=""
fi

echo "Collecting logcat for ${DURATION}s -> $LOG_PATH"
adb logcat -v brief > "$LOG_PATH" &
LOGCAT_PID="$!"
sleep "$DURATION"
kill "$LOGCAT_PID" >/dev/null 2>&1 || true
wait "$LOGCAT_PID" >/dev/null 2>&1 || true

if [ "$CAPTURE_MEDIA" != "0" ]; then
	wait "$SCREENRECORD_PID" >/dev/null 2>&1 || true
	adb pull "$REMOTE_VIDEO" "$VIDEO_PATH" >/dev/null 2>&1 || echo "Screen recording pull failed; keep manual recording if available."
	adb shell rm -f "$REMOTE_VIDEO" >/dev/null 2>&1 || true

	echo "Capturing screenshot -> $SCREENSHOT_PATH"
	adb exec-out screencap -p > "$SCREENSHOT_PATH" || echo "Screenshot capture failed; capture manually."
fi

echo "Validating gate: $GATE"
node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
	--gate "$GATE" \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS

EVIDENCE_ARGS=(--gate "$GATE" --screenshot "$SCREENSHOT_PATH" --video "$VIDEO_PATH" --report "$REPORT_PATH")
if [ "$ALLOW_MISSING_MEDIA" = "1" ]; then
	EVIDENCE_ARGS+=(--allow-missing-media)
fi

echo "Validating evidence bundle"
node "$PROJECT_ROOT/tools/c00/validate_evidence_bundle.js" "${EVIDENCE_ARGS[@]}"

if [ -f "$PROFILE_PATH" ]; then
	cat "$PROFILE_PATH" >> "$REPORT_PATH"
	echo "Device profile: $PROFILE_PATH"
fi
if [ -f "$PROFILE_ANALYSIS_PATH" ]; then
	cat "$PROFILE_ANALYSIS_PATH" >> "$REPORT_PATH"
	echo "Device profile analysis: $PROFILE_ANALYSIS_PATH"
fi

echo "Report: $REPORT_PATH"
