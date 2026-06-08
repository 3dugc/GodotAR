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
ANDROID_FORCE_STOP="${ANDROID_FORCE_STOP:-1}"
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
COLLECT_STATUS=0

mkdir -p "$OUT_DIR"

expected_xr_platform_arg() {
	case "$GATE" in
		rokid) printf "%s\n" "--xr-platform=rokid" ;;
		android-arcore) printf "%s\n" "--xr-platform=arcore" ;;
		*) printf "%s\n" "" ;;
	esac
}

check_apk_launch_args() {
	local apk="$1"
	local expected_arg
	expected_arg="$(expected_xr_platform_arg)"
	if [ -z "$expected_arg" ]; then
		return 0
	fi
	if [ -z "$apk" ]; then
		echo "APK_PATH is empty; runtime GXF_SMOKE must prove launch platform via cmdline/project metadata."
		return 0
	fi
	if [ ! -f "$apk" ]; then
		echo "APK not found: $apk" >&2
		return 2
	fi
	if ! command -v unzip >/dev/null 2>&1; then
		echo "unzip not found; cannot inspect APK assets/_cl_ for $expected_arg." >&2
		return 2
	fi

	local command_line
	command_line="$(unzip -p "$apk" assets/_cl_ 2>/dev/null || true)"
	if [ -z "$command_line" ]; then
		echo "APK does not contain assets/_cl_. Export preset must set command_line/extra_args to include $expected_arg." >&2
		return 2
	fi
	if ! printf "%s\n" "$command_line" | grep -q -- "$expected_arg"; then
		echo "APK assets/_cl_ does not include $expected_arg." >&2
		echo "Observed assets/_cl_: $command_line" >&2
		return 2
	fi
	echo "APK launch args include $expected_arg"
}

if ! command -v adb >/dev/null 2>&1; then
	echo "adb not found. Install Android platform tools and connect Rokid/Android device." >&2
	exit 2
fi

check_apk_launch_args "$APK_PATH"

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

if [ "$ANDROID_FORCE_STOP" != "0" ]; then
	echo "Force stopping package before launch: $PACKAGE"
	adb shell am force-stop "$PACKAGE" >/dev/null 2>&1 || true
fi

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
set +e
node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
	--gate "$GATE" \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS
SMOKE_STATUS="$?"
set -e
if [ "$SMOKE_STATUS" -ne 0 ]; then
	COLLECT_STATUS="$SMOKE_STATUS"
	echo "Smoke validation failed with exit $SMOKE_STATUS; continuing to evidence/profile report assembly." >&2
fi

EVIDENCE_ARGS=(--gate "$GATE" --screenshot "$SCREENSHOT_PATH" --video "$VIDEO_PATH" --report "$REPORT_PATH")
if [ "$ALLOW_MISSING_MEDIA" = "1" ]; then
	EVIDENCE_ARGS+=(--allow-missing-media)
fi

echo "Validating evidence bundle"
set +e
node "$PROJECT_ROOT/tools/c00/validate_evidence_bundle.js" "${EVIDENCE_ARGS[@]}"
EVIDENCE_STATUS="$?"
set -e
if [ "$EVIDENCE_STATUS" -ne 0 ]; then
	COLLECT_STATUS="$EVIDENCE_STATUS"
	echo "Evidence bundle validation failed with exit $EVIDENCE_STATUS; appending device diagnostics before exit." >&2
fi

if [ -f "$PROFILE_PATH" ]; then
	cat "$PROFILE_PATH" >> "$REPORT_PATH"
	echo "Device profile: $PROFILE_PATH"
fi
if [ -f "$PROFILE_ANALYSIS_PATH" ]; then
	cat "$PROFILE_ANALYSIS_PATH" >> "$REPORT_PATH"
	echo "Device profile analysis: $PROFILE_ANALYSIS_PATH"
fi

echo "Report: $REPORT_PATH"
exit "$COLLECT_STATUS"
