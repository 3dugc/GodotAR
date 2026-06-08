#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SIMULATOR_DEVICE="${1:-${SIMULATOR_DEVICE:-booted}}"
BUNDLE_ID="${2:-${BUNDLE_ID:-${PACKAGE:-org.godotengine.godotxrfoundation}}}"
DURATION="${3:-${DURATION:-30}}"
APP_PATH="${APP_PATH:-${IOS_SIMULATOR_APP_PATH:-$PROJECT_ROOT/builds/ios_simulator/GodotXRFoundation.app}}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
IOS_SIM_XR_PLATFORM="${IOS_SIM_XR_PLATFORM:-simulator}"
CAPTURE_MEDIA="${CAPTURE_MEDIA:-1}"
ALLOW_MISSING_MEDIA="${ALLOW_MISSING_MEDIA:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
LOG_PATH="$OUT_DIR/ios-simulator-${STAMP}.log"
REPORT_PATH="$OUT_DIR/ios-simulator-${STAMP}.md"
SCREENSHOT_PATH="$OUT_DIR/ios-simulator-${STAMP}.png"

usage() {
	cat <<EOF
Usage:
  APP_PATH=builds/ios_simulator/GodotXRFoundation.app tools/c00/collect_ios_simulator_smoke.sh [booted|simulator-udid] [bundle-id] [duration]

Environment:
  SIMULATOR_DEVICE=booted
  BUNDLE_ID=org.godotengine.godotxrfoundation
  IOS_SIM_XR_PLATFORM=simulator
  CAPTURE_MEDIA=1
  ALLOW_MISSING_MEDIA=0

This is a development gate. It validates iOS export/startup/log flow through
EditorSim on iOS Simulator. It does not satisfy the iPad/ARKit C00 publish gate.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

mkdir -p "$OUT_DIR"

if ! command -v xcrun >/dev/null 2>&1; then
	echo "xcrun not found. Install Xcode and select it with xcode-select." >&2
	exit 2
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
	echo "Simulator .app bundle is missing: $APP_PATH" >&2
	echo "Build it with IOS_BUILD_PLATFORM=simulator tools/c00/build_ios_xcode_project.sh <ios-export.zip>." >&2
	exit 2
fi

echo "Waiting for iOS Simulator device: $SIMULATOR_DEVICE"
if ! xcrun simctl bootstatus "$SIMULATOR_DEVICE" -b; then
	if [[ "$SIMULATOR_DEVICE" != "booted" ]]; then
		echo "Simulator is not booted. Trying to boot: $SIMULATOR_DEVICE"
		xcrun simctl boot "$SIMULATOR_DEVICE" || true
		if ! xcrun simctl bootstatus "$SIMULATOR_DEVICE" -b; then
			echo "Simulator did not boot or CoreSimulator is unavailable." >&2
			exit 2
		fi
	else
		echo "No booted simulator found or CoreSimulator is unavailable. Start a simulator in Xcode, or set SIMULATOR_DEVICE=<udid>." >&2
		exit 2
	fi
fi

echo "Installing simulator app: $APP_PATH"
xcrun simctl install "$SIMULATOR_DEVICE" "$APP_PATH"

echo "Launching $BUNDLE_ID on $SIMULATOR_DEVICE for ${DURATION}s -> $LOG_PATH"
set +e
xcrun simctl launch \
	--console-pty \
	--terminate-running-process \
	"$SIMULATOR_DEVICE" \
	"$BUNDLE_ID" \
	"--xr-platform=${IOS_SIM_XR_PLATFORM}" > "$LOG_PATH" 2>&1 &
LAUNCH_PID="$!"
sleep "$DURATION"
kill "$LAUNCH_PID" >/dev/null 2>&1 || true
wait "$LAUNCH_PID" >/dev/null 2>&1 || true
set -e

if ! grep -q "GXF_SMOKE" "$LOG_PATH"; then
	echo "No GXF_SMOKE from simctl launch console. Trying simulator unified log snapshot..."
	xcrun simctl spawn "$SIMULATOR_DEVICE" \
		log show \
		--last "${DURATION}s" \
		--style compact \
		--predicate 'eventMessage CONTAINS "GXF_SMOKE"' >> "$LOG_PATH" 2>&1 || true
fi

if [[ "$CAPTURE_MEDIA" != "0" ]]; then
	echo "Capturing iOS Simulator screenshot -> $SCREENSHOT_PATH"
	xcrun simctl io "$SIMULATOR_DEVICE" screenshot "$SCREENSHOT_PATH" >/dev/null 2>&1 || echo "iOS Simulator screenshot capture failed."
fi

echo "Validating iOS Simulator development gate"
node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
	--gate ios-simulator \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS

EVIDENCE_ARGS=(--gate ios-simulator --screenshot "$SCREENSHOT_PATH" --report "$REPORT_PATH")
if [[ "$ALLOW_MISSING_MEDIA" == "1" ]]; then
	EVIDENCE_ARGS+=(--allow-missing-media)
fi

echo "Validating iOS Simulator evidence bundle"
node "$PROJECT_ROOT/tools/c00/validate_evidence_bundle.js" "${EVIDENCE_ARGS[@]}"

echo "Report: $REPORT_PATH"
