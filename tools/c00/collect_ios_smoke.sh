#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE="${1:-}"
BUNDLE_ID="${2:-org.godotengine.godotxrfoundation}"
DURATION="${3:-30}"
APP_PATH="${APP_PATH:-}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
IOS_XR_PLATFORM="${IOS_XR_PLATFORM:-ipad}"
CAPTURE_MEDIA="${CAPTURE_MEDIA:-1}"
ALLOW_MISSING_MEDIA="${ALLOW_MISSING_MEDIA:-0}"
MANUAL_MEDIA_PATH="${MANUAL_MEDIA_PATH:-}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
LOG_PATH="$OUT_DIR/ipad-${STAMP}.log"
REPORT_PATH="$OUT_DIR/ipad-${STAMP}.md"
SCREENSHOT_PATH="$OUT_DIR/ipad-${STAMP}.png"
PROFILE_PATH="$OUT_DIR/ipad-${STAMP}-device.md"
PROFILE_JSON_PATH="$OUT_DIR/ipad-${STAMP}-device.json"
PROFILE_ANALYSIS_PATH="$OUT_DIR/ipad-${STAMP}-device-analysis.md"
COLLECT_STATUS=0

mkdir -p "$OUT_DIR"

if ! command -v xcrun >/dev/null 2>&1; then
	echo "xcrun not found. Install Xcode and select it with xcode-select." >&2
	exit 2
fi

if [ -z "$DEVICE" ]; then
	echo "Device argument is required. Run: xcrun devicectl list devices"
	exit 2
fi

if [ -n "$APP_PATH" ]; then
	echo "Installing app bundle: $APP_PATH"
	set +e
	xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"
	INSTALL_STATUS="$?"
	set -e
	if [ "$INSTALL_STATUS" -ne 0 ]; then
		COLLECT_STATUS="$INSTALL_STATUS"
		echo "iPad app install failed with exit $INSTALL_STATUS; continuing to device profile and smoke diagnostics." >&2
	fi
fi

echo "Collecting iPad device profile -> $PROFILE_PATH"
if ! node "$PROJECT_ROOT/tools/c00/collect_ios_device_profile.js" \
	--device "$DEVICE" \
	--bundle "$BUNDLE_ID" \
	--report "$PROFILE_PATH" \
	--json "$PROFILE_JSON_PATH"; then
	echo "iPad device profile collection failed; continuing to smoke collection."
fi

if [ -f "$PROFILE_JSON_PATH" ]; then
	echo "Analyzing iPad device profile -> $PROFILE_ANALYSIS_PATH"
	if ! node "$PROJECT_ROOT/tools/c00/analyze_ios_device_profile.js" \
		--json "$PROFILE_JSON_PATH" \
		--report "$PROFILE_ANALYSIS_PATH"; then
		echo "iPad device profile analysis reported failures; final gate still depends on smoke log validation."
	fi
fi

echo "Launching $BUNDLE_ID on $DEVICE with console capture for ${DURATION}s"
set +e
xcrun devicectl \
	--timeout "$DURATION" \
	device process launch \
	--device "$DEVICE" \
	--terminate-existing \
	--console \
	"$BUNDLE_ID" \
	"--xr-platform=${IOS_XR_PLATFORM}" > "$LOG_PATH" 2>&1
LAUNCH_STATUS="$?"
set -e

if ! grep -q "GXF_SMOKE" "$LOG_PATH"; then
	if command -v idevicesyslog >/dev/null 2>&1; then
		echo "No GXF_SMOKE from devicectl console. Trying idevicesyslog for ${DURATION}s..."
		idevicesyslog > "$LOG_PATH" &
		LOG_PID="$!"
		sleep "$DURATION"
		kill "$LOG_PID" >/dev/null 2>&1 || true
		wait "$LOG_PID" >/dev/null 2>&1 || true
	elif command -v pymobiledevice3 >/dev/null 2>&1; then
		echo "No GXF_SMOKE from devicectl console. Trying pymobiledevice3 syslog for ${DURATION}s..."
		pymobiledevice3 syslog live > "$LOG_PATH" &
		LOG_PID="$!"
		sleep "$DURATION"
		kill "$LOG_PID" >/dev/null 2>&1 || true
		wait "$LOG_PID" >/dev/null 2>&1 || true
	else
		echo "No iOS syslog tool found. If validation fails, export logs from Xcode/Console.app and run validate_smoke_log.js manually."
	fi
fi

if [ "$CAPTURE_MEDIA" != "0" ]; then
	if command -v idevicescreenshot >/dev/null 2>&1; then
		echo "Capturing iOS screenshot -> $SCREENSHOT_PATH"
		idevicescreenshot "$SCREENSHOT_PATH" >/dev/null 2>&1 || echo "iOS screenshot capture failed; capture screenshot or 15s recording manually."
	else
		echo "No iOS screenshot tool found. Capture a screenshot or 15s recording manually, then set MANUAL_MEDIA_PATH for the C00 evidence bundle."
	fi
fi

echo "devicectl launch status: $LAUNCH_STATUS"
echo "Validating iPad gate"
set +e
node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
	--gate ipad \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS
SMOKE_STATUS="$?"
set -e
if [ "$SMOKE_STATUS" -ne 0 ]; then
	COLLECT_STATUS="$SMOKE_STATUS"
	echo "Smoke validation failed with exit $SMOKE_STATUS; continuing to evidence/profile report assembly." >&2
fi

EVIDENCE_ARGS=(--gate ipad --screenshot "$SCREENSHOT_PATH" --report "$REPORT_PATH")
if [ -n "$MANUAL_MEDIA_PATH" ]; then
	EVIDENCE_ARGS+=(--manual-media "$MANUAL_MEDIA_PATH")
fi
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
