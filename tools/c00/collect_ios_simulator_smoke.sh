#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SIMULATOR_DEVICE="${1:-${SIMULATOR_DEVICE:-booted}}"
BUNDLE_ID="${2:-${BUNDLE_ID:-${PACKAGE:-org.godotengine.godotxrfoundation}}}"
DURATION="${3:-${DURATION:-30}}"
APP_PATH="${APP_PATH:-${IOS_SIMULATOR_APP_PATH:-$PROJECT_ROOT/builds/ios_simulator/GodotXRFoundation.app}}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
IOS_SIM_XR_PLATFORM="${IOS_SIM_XR_PLATFORM:-simulator}"
IOS_SIM_XR_SCENE="${IOS_SIM_XR_SCENE:-}"
IOS_SIM_GATE="${IOS_SIM_GATE:-ios-simulator}"
CAPTURE_MEDIA="${CAPTURE_MEDIA:-1}"
ALLOW_MISSING_MEDIA="${ALLOW_MISSING_MEDIA:-0}"
SIMULATOR_REQUIRED_ARCHS="${SIMULATOR_REQUIRED_ARCHS:-auto}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
EVIDENCE_PREFIX="${IOS_SIM_GATE//[^A-Za-z0-9_-]/-}"
LOG_PATH="$OUT_DIR/${EVIDENCE_PREFIX}-${STAMP}.log"
REPORT_PATH="$OUT_DIR/${EVIDENCE_PREFIX}-${STAMP}.md"
SCREENSHOT_PATH="$OUT_DIR/${EVIDENCE_PREFIX}-${STAMP}.png"

usage() {
	cat <<EOF
Usage:
  APP_PATH=builds/ios_simulator/GodotXRFoundation.app tools/c00/collect_ios_simulator_smoke.sh [booted|simulator-udid] [bundle-id] [duration]

Environment:
  SIMULATOR_DEVICE=booted
  BUNDLE_ID=org.godotengine.godotxrfoundation
  IOS_SIM_XR_PLATFORM=simulator
  IOS_SIM_XR_SCENE=                 Optional boot router scene alias, for example ios_arkit_place.
  IOS_SIM_GATE=ios-simulator        Development validator gate. Use ios-simulator-place for C04 placement.
  CAPTURE_MEDIA=1
  ALLOW_MISSING_MEDIA=0
  SIMULATOR_REQUIRED_ARCHS=auto | arm64 | x86_64 | "arm64 x86_64"

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

app_executable_path() {
	local executable="" candidate=""
	if [[ -f "$APP_PATH/Info.plist" && -x /usr/libexec/PlistBuddy ]]; then
		executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist" 2>/dev/null || true)"
	fi
	if [[ -n "$executable" && -f "$APP_PATH/$executable" ]]; then
		printf "%s" "$APP_PATH/$executable"
		return 0
	fi
	for candidate in "$APP_PATH"/*; do
		if [[ -f "$candidate" && -x "$candidate" ]]; then
			printf "%s" "$candidate"
			return 0
		fi
	done
	return 1
}

simulator_required_archs() {
	if [[ "$SIMULATOR_REQUIRED_ARCHS" != "auto" ]]; then
		printf "%s" "$SIMULATOR_REQUIRED_ARCHS"
		return 0
	fi
	case "$(uname -m)" in
		arm64) printf "arm64" ;;
		x86_64) printf "x86_64" ;;
		*) uname -m ;;
	esac
}

write_simulator_arch_failure_report() {
	local executable="$1" required_archs="$2" actual_archs="$3"
	{
		echo "GXF_SMOKE_SIMULATOR_ARCH_CHECK pass=false"
		echo "reason=missing_simulator_arch"
		echo "app_path=$APP_PATH"
		echo "executable=$executable"
		echo "required_archs=$required_archs"
		echo "actual_archs=$actual_archs"
		echo "host_arch=$(uname -m)"
	} > "$LOG_PATH"
	{
		echo "# iOS Simulator Development Gate"
		echo
		echo "- Result: Fail"
		echo "- Reason: missing_simulator_arch"
		echo "- App: \`$APP_PATH\`"
		echo "- Executable: \`$executable\`"
		echo "- Required simulator archs: \`$required_archs\`"
		echo "- App executable archs: \`$actual_archs\`"
		echo "- Host arch: \`$(uname -m)\`"
		echo
		echo "The app cannot be installed on this simulator runtime until the Godot iOS Simulator export template contains a matching architecture slice."
	} > "$REPORT_PATH"
}

if ! EXECUTABLE_PATH="$(app_executable_path)"; then
	echo "Simulator .app executable is missing in: $APP_PATH" >&2
	exit 2
fi
APP_ARCHS="$(lipo -archs "$EXECUTABLE_PATH" 2>/dev/null || true)"
if [[ -z "$APP_ARCHS" ]]; then
	echo "Could not inspect simulator app executable architectures: $EXECUTABLE_PATH" >&2
	exit 2
fi
REQUIRED_ARCHS="$(simulator_required_archs)"
HAS_REQUIRED_ARCH=0
for required_arch in $REQUIRED_ARCHS; do
	for app_arch in $APP_ARCHS; do
		if [[ "$required_arch" == "$app_arch" ]]; then
			HAS_REQUIRED_ARCH=1
			break
		fi
	done
done
if [[ "$HAS_REQUIRED_ARCH" != "1" ]]; then
	write_simulator_arch_failure_report "$EXECUTABLE_PATH" "$REQUIRED_ARCHS" "$APP_ARCHS"
	echo "Simulator app executable lacks a required architecture slice." >&2
	echo "Executable: $EXECUTABLE_PATH" >&2
	echo "Required simulator archs: $REQUIRED_ARCHS" >&2
	echo "App executable archs: $APP_ARCHS" >&2
	echo "Report: $REPORT_PATH" >&2
	exit 4
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
LAUNCH_ARGS=("--xr-platform=${IOS_SIM_XR_PLATFORM}")
if [[ -n "$IOS_SIM_XR_SCENE" ]]; then
	LAUNCH_ARGS+=("--xr-scene=${IOS_SIM_XR_SCENE}")
fi
set +e
xcrun simctl launch \
	--console-pty \
	--terminate-running-process \
	"$SIMULATOR_DEVICE" \
	"$BUNDLE_ID" \
	"${LAUNCH_ARGS[@]}" > "$LOG_PATH" 2>&1 &
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
	--gate "$IOS_SIM_GATE" \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS

EVIDENCE_ARGS=(--gate "$IOS_SIM_GATE" --screenshot "$SCREENSHOT_PATH" --report "$REPORT_PATH")
if [[ "$ALLOW_MISSING_MEDIA" == "1" ]]; then
	EVIDENCE_ARGS+=(--allow-missing-media)
fi

echo "Validating iOS Simulator evidence bundle"
node "$PROJECT_ROOT/tools/c00/validate_evidence_bundle.js" "${EVIDENCE_ARGS[@]}"

echo "Report: $REPORT_PATH"
